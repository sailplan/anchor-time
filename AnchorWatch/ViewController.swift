import UIKit
import MapKit
import UserNotifications

class ViewController: UIViewController {
    //MARK: - Properties
    let locationManager = CLLocationManager()
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
            anchorage?.radius = newValue
        }
    }

    var mkCircleRenderer : GeofenceMKCircleRenderer?
    var isGeofenceResizingAllowed : Bool = false {
        didSet {
            if isGeofenceResizingAllowed != oldValue {
                //                self.mapView.isRotateEnabled = !isGeofenceResizingAllowed
                //                self.mapView.isScrollEnabled = !isGeofenceResizingAllowed
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

        UIDevice.current.isBatteryMonitoringEnabled = true
        NotificationCenter.default.addObserver(self, selector: #selector(batteryLevelDidChange(_:)), name: UIDevice.batteryLevelDidChangeNotification, object: nil)

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

        updateUI()
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
        mapView.setUserTrackingMode(.follow, animated: true)
    }

    //MARK: - Observers

    @objc func didChangeState(_ notification:Notification) {
        switch anchorage!.state {
        case .dragging:
            deliverNotification()
            activateAlarm()
        default:
            print("Anchorage state changed", anchorage!.state)
            // no worries
        }
    }

    // Trigger a notification if battery gets low
    @objc func batteryLevelDidChange(_ notification:Notification) {
        // Do nothing if anchorage is not set
        guard anchorage?.state == .set else { return }

        let batteryState = UIDevice.current.batteryState
        let batteryLevel = UIDevice.current.batteryLevel

        // Do nothing if battery is charging or is not low
        if (batteryState == .charging || batteryLevel > 0.2) {
            return
        }

        print("Battery low", batteryLevel)

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

        // Only play alarm if battery is critically low.
        if (batteryLevel <= 0.1) {
            activateAlarm()
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
        mkCircleRenderer?.set(radius: circle!.radius)

        anchorPositionLabel.text = FormatDisplay.coordinate(anchorage.coordinate)
        anchorageRadiusLabel.text = FormatDisplay.distance(radius)
    }

    func updateUI(animated: Bool = true) {
        UIView.setAnimationsEnabled(animated)

        if let anchorage = self.anchorage {
            dashboardConstraint.isActive = false
            dropAnchorButton.isHidden = true

            UIView.animate(withDuration: 0.2, animations: {
                self.userTrackingModeButton.superview!.alpha = 0
            }) { (finished) in
                self.userTrackingModeButton.superview!.isHidden = true
            }

            setButton.isHidden = anchorage.state != .dropped
            stopButton.isHidden = anchorage.state != .set
            cancelButton.isHidden = anchorage.state == .set

            // Stop following user's current location
            mapView.setUserTrackingMode(MKUserTrackingMode.none, animated: true)
            mapView.isZoomEnabled = false
            mapView.isScrollEnabled = anchorage.state != .set

            scrollAnchorageIntoView()
        } else {
            dashboardConstraint.isActive = true
            dropAnchorButton.isHidden = false

            UIView.animate(withDuration: 0.2, animations: {
                self.userTrackingModeButton.superview!.alpha = 1
            }) { (finished) in
                self.userTrackingModeButton.superview!.isHidden = false
            }

            // Start following user's current location
            mapView.setUserTrackingMode(MKUserTrackingMode.follow, animated: true)
            mapView.isZoomEnabled = true
            mapView.isScrollEnabled = true
        }

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
        gpsAccuracyLabel.text = "+/- \(FormatDisplay.distance(location.horizontalAccuracy))"

        guard let anchorage = self.anchorage else { return }

        if let lastLocation = anchorage.locations.last {
            let coordinates = [lastLocation.coordinate, location.coordinate]
            mapView.addOverlay(MKPolyline(coordinates: coordinates, count: 2))
        }

        anchorBearingLabel.text = FormatDisplay.degrees(anchorage.bearingFrom(location.coordinate))
        anchorDistanceLabel.text = FormatDisplay.distance(anchorage.distanceTo(location))
        anchorage.track(location)

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

    func activateAlarm() {
        let alertController = UIAlertController(
            title: "Anchor dragging",
            message: nil,
            preferredStyle: .alert
        )

        alertController.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.alarm.stop()
        })

        present(alertController, animated: true)

        alarm.start()
    }

    func addGestureRecognizer() {
        let gestureRecognizer = GeofenceGestureRecognizer()
        self.mapView.addGestureRecognizer(gestureRecognizer)
        gestureRecognizer.touchesBeganCallback = { ( touches: Set<UITouch>, event : UIEvent) in
            if let touch = touches.first {
                self.mapView.isScrollEnabled = false
                let pointOnMapView = touch.location(in: self.mapView)
                let coordinateFromPoint = self.mapView.convert(pointOnMapView, toCoordinateFrom: self.mapView)
                let mapPoint = MKMapPoint(coordinateFromPoint)
                if let fenceRederer = self.mkCircleRenderer {
                    if let thumbMapRect = fenceRederer.thumbBounds {
                        /* get rect of thumb */
                        if thumbMapRect.contains(mapPoint) {
                            /* touched on thumb */
                            self.isGeofenceResizingAllowed = true
                            self.oldFenceRadius = fenceRederer.getRadius()
                        }                    }
                }
                self.lastMapPoint = mapPoint
            }
        }
        gestureRecognizer.touchesMovedCallback = { ( touches: Set<UITouch>, event : UIEvent) in
            /* if resizing is allowed and only one touch is processed perform resizing */
            if self.isGeofenceResizingAllowed && touches.count == 1 {

                if let touch = touches.first {
                    let pointOnMapView = touch.location(in: self.mapView)
                    let coordinateFromPoint = self.mapView.convert(pointOnMapView, toCoordinateFrom: self.mapView)
                    let mapPoint = MKMapPoint(coordinateFromPoint)

                    if let lastPoint = self.lastMapPoint {
                        var meterDistance = (mapPoint.x-lastPoint.x)/MKMapPointsPerMeterAtLatitude(coordinateFromPoint.latitude)+self.oldFenceRadius
                        if meterDistance > 0 {
                            //                            if abs(meterDistance-self.oldFenceRadius) >= DEFAULT_STEP_RADIUS {
                            self.mkCircleRenderer?.set(radius: meterDistance)
                            if let rad = self.mkCircleRenderer?.getRadius() {
                                meterDistance = rad
                            }
                            //                            }
                        }
                    }
                }
            }
        }

        gestureRecognizer.touchesEndedCallback = { ( touches: Set<UITouch>, event : UIEvent) in

            if self.isGeofenceResizingAllowed && touches.count == 1 {
                if let _ = touches.first {
                    self.mapView.isScrollEnabled = true

                    if let circleRenderer = self.mkCircleRenderer {
                        let radius = circleRenderer.getRadius()
                        let zoomCoordinate = circleRenderer.circle.coordinate
                        let zoomRadius = radius*4
                        self.mapView.setRegion(MKCoordinateRegion(center: zoomCoordinate, latitudinalMeters: zoomRadius, longitudinalMeters: zoomRadius), animated: false)
                        circleRenderer.set(radius: radius)
                    }
                }
            }


            self.isGeofenceResizingAllowed = false
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
