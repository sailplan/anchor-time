import UIKit
import MapKit
import UserNotifications

class ViewController: UIViewController {
    //MARK: - Properties
    let locationManager = CLLocationManager()
    let batteryMonitor = BatteryMonitor()
    let alarm = Alarm()
    let notificationCenter = UNUserNotificationCenter.current()

    var notificationContent: UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.body = "Your anchor is dragging!"
        content.sound = UNNotificationSound.defaultCriticalSound(withAudioVolume: 1.0)
        return content
    }

    var anchorage: Anchorage?
    var circle: MKCircle?
    var dashboardConstraint: NSLayoutConstraint!

    var radius: CLLocationDistance {
        get {
            return anchorage?.radius ?? 0
        }

        set {
            print("Changed anchorage radius to", radius)
            anchorage?.radius = newValue
            scrollAnchorageIntoView()
        }
    }

    var mkCircleRenderer : GeofenceMKCircleRenderer?
    var isResizing : Bool = false {
        didSet {
            self.mapView.isScrollEnabled = !isResizing
        }
    }
    var allowsResizing: Bool {
        get {
            return anchorage?.state == .dropped
        }
    }

    var isMapInteractive: Bool = false {
        didSet {
            mapView.isZoomEnabled = isMapInteractive
            mapView.isScrollEnabled = isMapInteractive

            UIView.animate(withDuration: 0.2, animations: {
                self.userTrackingModeButton.superview?.alpha = self.isMapInteractive ? 1 : 0
            }) { (finished) in
                self.userTrackingModeButton.superview?.isHidden = !self.isMapInteractive
            }
        }
    }

    fileprivate var lastMapPoint : MKMapPoint? = nil
    fileprivate var oldFenceRadius : Double = 0.0

    //MARK: - Outlets
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var dropAnchorButton: UIView!
    @IBOutlet weak var dashboardView: UIView!
    @IBOutlet weak var setButton: UIButton!
    @IBOutlet weak var stopButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var anchorPositionLabel: UILabel!
    @IBOutlet weak var anchorageRadiusLabel: UILabel!
    @IBOutlet weak var gpsAccuracyLabel: UILabel!
    @IBOutlet weak var anchorBearingLabel: UILabel!
    @IBOutlet weak var anchorDistanceLabel: UILabel!
    @IBOutlet weak var userTrackingModeButton: UIButton!

    //MARK: - Life cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        batteryMonitor.delegate = self
        mapView.delegate = self

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.showsBackgroundLocationIndicator = true
        locationManager.requestAlwaysAuthorization()

        // Add hidden volume view so we can control volume
        self.view.addSubview(alarm.volumeView)

        NotificationCenter.default.addObserver(self, selector: #selector(didChangeState(_:)), name: .didChangeState, object: nil)

        // Move dashboard off bottom of the screen
        dashboardConstraint = dashboardView.topAnchor.constraint(equalTo: view.bottomAnchor)
        dashboardConstraint.isActive = true

        dashboardView.layer.shadowColor = UIColor.black.cgColor
        dashboardView.layer.shadowOpacity = 0.4
        dashboardView.layer.shadowOffset = CGSize.zero
        dashboardView.layer.shadowRadius = 4

        self.anchorage = Anchorage.load()
        renderAnchorage()
        updateUI(animated: false)
        addGestureRecognizer()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        print("Received memory warning")
    }

    //MARK: - Actions

    @IBAction func dropAnchor(_ sender: Any) {
        anchorage = Anchorage(coordinate: mapView.centerCoordinate)
        print("Anchor dropped", anchorage!.coordinate)

        // Ensure anchorage includes current location to start
        if let location = locationManager.location {
            anchorage!.widen(location)
        }

        locationManager.startUpdatingLocation()
        renderAnchorage()
        updateUI()
    }

    @IBAction func setAnchor(_ sender: Any) {
        guard let anchorage = self.anchorage else { return }
        anchorage.set()
        print("Anchor set", anchorage.coordinate, radius)

        renderCircle()
        updateUI()
    }

    @IBAction func stopTapped(_ sender: Any) {
        let alertController = UIAlertController(
            title: "Are you sure?",
            message: "Do you want to turn off the anchor alarm and stop monitoring this anchorage?",
            preferredStyle: .actionSheet
        )

        alertController.addAction(UIAlertAction(title: "Reset", style: .default) { _ in
            self.anchorage?.reset()
            self.updateUI()
        })

        alertController.addAction(UIAlertAction(title: "Stop", style: .destructive) { _ in
            self.cancel(self)
        })

        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        present(alertController, animated: true)
    }

    @IBAction func cancel(_ sender: Any) {
        guard let anchorage = self.anchorage else { return }

        // Remove map overlays
        mapView.removeAnnotation(anchorage)
        mapView.removeOverlays(mapView.overlays)
        if(circle != nil) {
            mapView.removeOverlay(circle!)
            self.circle = nil
        }

        notificationCenter.removeAllPendingNotificationRequests()

        // Reset Model
        anchorage.clear()
        self.anchorage = nil

        alarm.stop()
        locationManager.stopUpdatingLocation()
        updateUI()
    }

    @IBAction func followUserTapped() {
        if anchorage?.state == .dropped, let location = locationManager.location {
            mapView.centerCoordinate = location.coordinate
        } else {
            mapView.setUserTrackingMode(.follow, animated: true)
        }
    }

    //MARK: - Observers

    @objc func didChangeState(_ notification:Notification) {
        switch anchorage!.state {
        case .dragging:
            deliverNotification()
            didExitAnchorage()
        default:
            print("Anchorage state changed", anchorage!.state)
            // no worries
        }
    }

    //MARK: - View concerns

    func renderAnchorage() {
        guard let anchorage = self.anchorage else { return }

        // Add anchorage to the map
        mapView.addAnnotation(anchorage)

        renderCircle()
    }

    func renderCircle() {
        guard let anchorage = self.anchorage else { return }

        if (circle != nil) {
            mapView.removeOverlay(circle!)
        }

        circle = anchorage.circle
        mapView.addOverlay(circle!)

        anchorPositionLabel.text = FormatDisplay.coordinate(anchorage.coordinate)
        anchorageRadiusLabel.text = FormatDisplay.distance(radius)
    }

    func updateUI(animated: Bool = true) {
        UIView.setAnimationsEnabled(animated)

        if let anchorage = self.anchorage {
            dashboardConstraint.isActive = false
            dropAnchorButton.isHidden = true

            setButton.isHidden = anchorage.state != .dropped
            stopButton.isHidden = anchorage.state != .set
            cancelButton.isHidden = anchorage.state == .set

            // Stop following user's current location
            mapView.setUserTrackingMode(MKUserTrackingMode.none, animated: true)

            scrollAnchorageIntoView()
        } else {
            dashboardConstraint.isActive = true
            dropAnchorButton.isHidden = false

            // Start following user's current location
            mapView.setUserTrackingMode(MKUserTrackingMode.follow, animated: true)
        }

        self.isMapInteractive = anchorage == nil || anchorage?.state == .dropped

        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }

        // Always re-enable animations
        UIView.setAnimationsEnabled(true)
    }

    func scrollAnchorageIntoView() {
        guard let anchorage = anchorage else { return }

        // Center map on anchorage
        mapView.setRegion(mapView.regionThatFits(anchorage.region), animated: true)
    }

    //MARK: - App Logic

    func updateLocation(location: CLLocation) {
        // Always update GPS accuracy
        gpsAccuracyLabel.text = "+/- \(FormatDisplay.distance(location.horizontalAccuracy))"

        // Ensure an anchorage is active and the location should be tracked
        guard let anchorage = self.anchorage, let track = anchorage.track(location) else {
            return
        }

        // Draw the track from the previews location on the map
        if track.previous != nil {
            let coordinates = [track.previous!.coordinate, location.coordinate]
            mapView.addOverlay(MKPolyline(coordinates: coordinates, count: 2))
        }

        anchorBearingLabel.text = FormatDisplay.degrees(anchorage.bearingFrom(location.coordinate))
        anchorDistanceLabel.text = FormatDisplay.distance(anchorage.distanceTo(location))

        switch anchorage.state {
        case .dropped:
            anchorage.widen(location)
            renderCircle()
            scrollAnchorageIntoView()
        case .set:
            anchorage.check(location)
        case .dragging:
            // TODO: already dragging
            break
        }
    }

    func deliverNotification() {
        let request = UNNotificationRequest(
            identifier: "dragging",
            content: notificationContent,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        notificationCenter.add(request) { error in
            if let error = error {
                print("Error: \(error)")
            }
        }
    }

    func didExitAnchorage() {
        let alertController = UIAlertController(
            title: "Drag warning",
            message: "Your anchor might be dragging.",
            preferredStyle: .actionSheet
        )

        alertController.addAction(UIAlertAction(title: "Reset", style: .default) { _ in
            self.alarm.stop()
            self.anchorage?.reset()
            self.updateUI()
        })

        alertController.addAction(UIAlertAction(title: "Stop", style: .destructive) { _ in
            self.alarm.stop()
            self.cancel(self)
        })

        present(alertController, animated: true)

        alarm.start()
    }

    func addGestureRecognizer() {
        let gestureRecognizer = GeofenceGestureRecognizer()
        self.mapView.addGestureRecognizer(gestureRecognizer)

        gestureRecognizer.touchesBeganCallback = { ( touches: Set<UITouch>, event : UIEvent) in
            guard let mkCircleRenderer = self.mkCircleRenderer,
                let thumbMapRect = mkCircleRenderer.thumbBounds,
                let touch = touches.first
                else { return }

            let pointOnMapView = touch.location(in: self.mapView)
            let coordinateFromPoint = self.mapView.convert(pointOnMapView, toCoordinateFrom: self.mapView)
            let mapPoint = MKMapPoint(coordinateFromPoint)

            // Check that touch is on thumb
            if thumbMapRect.contains(mapPoint) {
                self.isResizing = true
                self.oldFenceRadius = mkCircleRenderer.radius
                self.lastMapPoint = mapPoint
            }
        }

        gestureRecognizer.touchesMovedCallback = { ( touches: Set<UITouch>, event : UIEvent) in
            // Only perform resize if resizing is active and there's one touch
            guard self.isResizing && touches.count == 1,
                let touch = touches.first,
                let lastPoint = self.lastMapPoint
                else { return }

            let pointOnMapView = touch.location(in: self.mapView)
            let coordinateFromPoint = self.mapView.convert(pointOnMapView, toCoordinateFrom: self.mapView)
            let mapPoint = MKMapPoint(coordinateFromPoint)

            let distance = (mapPoint.x - lastPoint.x) / MKMapPointsPerMeterAtLatitude(coordinateFromPoint.latitude) + self.oldFenceRadius
            if distance > 0 {
                self.mkCircleRenderer?.radius = distance
            }
        }

        gestureRecognizer.touchesEndedCallback = { ( touches: Set<UITouch>, event : UIEvent) in
            guard self.isResizing && touches.count == 1 else { return }
            self.isResizing = false
        }
    }

}

//MARK: - Core Location
extension ViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        mapView.showsUserLocation = (status == .authorizedAlways)
    }

    func locationManager(_ manager: CLLocationManager,  didUpdateLocations locations: [CLLocation]) {
        updateLocation(location: locations.last!)
    }
}

//MARK: - MapKit
extension ViewController: MKMapViewDelegate {
    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        guard let anchorage = anchorage else { return }
        anchorage.coordinate = mapView.centerCoordinate

        // Ensure anchorage includes current location
        if let location = locationManager.location {
            anchorage.widen(location)
        }

        renderCircle()
    }

    func mapView(_ mapView: MKMapView, didChange mode: MKUserTrackingMode, animated: Bool) {
        userTrackingModeButton.tintColor = mode == .follow ? view.tintColor : UIColor.darkGray
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        var view : MKMarkerAnnotationView
        guard let annotation = annotation as? Anchorage else { return nil }
        if let dequeuedView = mapView.dequeueReusableAnnotationView(withIdentifier: annotation.identifier) as? MKMarkerAnnotationView {
            view = dequeuedView
        } else { // make a new view
            view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: annotation.identifier)
            view.glyphImage = UIImage(named: "anchor")
            view.markerTintColor = self.view.tintColor
        }
        return view
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        switch overlay {
        case is MKCircle:
            mkCircleRenderer = GeofenceMKCircleRenderer(circle: overlay as! MKCircle)
            mkCircleRenderer!.delegate = self
            mkCircleRenderer!.isResizeable = self.allowsResizing
            return mkCircleRenderer!
        case let polyline as MKPolyline:
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = .yellow
            renderer.lineWidth = 1
            return renderer
        default:
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

extension ViewController : GeofenceMKCircleRendererDelegate {
    func onRadiusChange(radius: Double) {
        self.radius = radius
    }
}

extension ViewController: BatteryMonitorDelegate {
    func isBatteryMonitoringEnabled() -> Bool {
        return anchorage?.state == .set
    }

    func batteryLow(level: Float) {
        print("Battery low", level)

        let content = UNMutableNotificationContent()
        content.title = "Low battery!"
        content.body = "Plug in your device to continue monitoring your anchorage."
        content.sound = UNNotificationSound.default

        let request = UNNotificationRequest(
            identifier: "low-battery",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        notificationCenter.add(request)
    }

    func batteryCritical(level: Float) {
        batteryLow(level: level)
        alarm.start()
    }
}
