import UIKit
import MapKit
import UserNotifications
import AVFoundation
import MediaPlayer

class ViewController: UIViewController {
    //MARK: - Properties
    let locationManager = CLLocationManager()
    let notificationCenter = UNUserNotificationCenter.current()
    var alarm: AVAudioPlayer?
    let volumeView = MPVolumeView(frame: CGRect(x: -CGFloat.greatestFiniteMagnitude, y: 0.0, width: 0.0, height: 0.0))

    var anchorage: Anchorage?
    var circle: MKCircle?

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

    var notificationContent: UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.body = "Your anchor is dragging!"
        content.sound = UNNotificationSound.defaultCriticalSound(withAudioVolume: 1.0)
        return content
    }

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
        locationManager.startUpdatingLocation()

        // Add hidden volume view so we can control volume
        self.view.addSubview(volumeView)

        NotificationCenter.default.addObserver(self, selector: #selector(didChangeState(_:)), name: .didChangeState, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(volumeDidChange(_:)), name: .volumeDidChange, object: nil)

        UIDevice.current.isBatteryMonitoringEnabled = true
        NotificationCenter.default.addObserver(self, selector: #selector(batteryLevelDidChange(_:)), name: UIDevice.batteryLevelDidChangeNotification, object: nil)

        self.anchorage = Anchorage.load()
        renderAnchorage()
        updateUI()
    }

    //MARK: - App logic

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
    
    @IBAction func dropAnchor(_ sender: Any) {
        anchorage = Anchorage(coordinate: mapView.centerCoordinate)
        // Ensure anchorage includes current location to start
        anchorage!.widen(locationManager.location!)

        print("Anchor dropped", anchorage!.coordinate)

        renderAnchorage()
        updateUI()
    }
    
    @IBAction func setAnchor(_ sender: Any) {
        guard let anchorage = self.anchorage else { return }
        anchorage.set()
        print("Anchor set", anchorage.coordinate, anchorage.radius)

        updateUI()
        setupAlarm()
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

        stopAlarm()
        updateUI()
    }

    @IBAction func followUserTapped() {
        mapView.setUserTrackingMode(.follow, animated: true)
    }

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
        anchorageRadiusLabel.text = FormatDisplay.distance(anchorage.radius)
    }
    
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

    func updateUI() {
        if let anchorage = self.anchorage {
            dashboardView.isHidden = false
            dropAnchorButton.isHidden = true
            userTrackingModeButton.superview!.isHidden = true

            setButton.isHidden = anchorage.state != .dropped
            stopButton.isHidden = anchorage.state != .set
            cancelButton.isHidden = anchorage.state == .set

            // Stop following user's current location
            mapView.setUserTrackingMode(MKUserTrackingMode.none, animated: true)
            mapView.isZoomEnabled = false
            mapView.isScrollEnabled = anchorage.state != .set

            scrollAnchorageIntoView()
        } else {
            dashboardView.isHidden = true
            dropAnchorButton.isHidden = false
            userTrackingModeButton.superview!.isHidden = false

            // Start following user's current location
            mapView.setUserTrackingMode(MKUserTrackingMode.follow, animated: true)
            mapView.isZoomEnabled = true
            mapView.isScrollEnabled = true
        }
    }

    func scrollAnchorageIntoView() {
        guard let anchorage = anchorage else { return }

        // Center map on anchorage
        mapView.setRegion(mapView.regionThatFits(anchorage.region), animated: true)
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

    @objc func volumeDidChange(_ notification:Notification) {
        print("Volume buttons pressed")
        stopAlarm()
    }

    func activateAlarm() {
        let alertController = UIAlertController(
            title: "Anchor dragging",
            message: nil,
            preferredStyle: .alert
        )

        alertController.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.stopAlarm()
        })

        present(alertController, animated: true)

        volumeView.setVolume(1.0)
        alarm?.play()
    }

    func stopAlarm() {
        alarm?.stop()
    }

    func showAlert(withTitle title: String?, message: String?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .cancel, handler: nil)
        alert.addAction(action)
        present(alert, animated: true, completion: nil)
    }

    func setupAlarm() {
        // Ensure audio plays even if in silent mode
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers, .defaultToSpeaker])
        } catch {
            print("Setting category to AVAudioSessionCategoryPlayback failed", error.localizedDescription)
        }
        
        let fileURL = Bundle.main.path(forResource: "alarm", ofType: "mp3")
        do {
            alarm = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: fileURL!))
        } catch let error {
            print("Can't play the audio file failed with an error \(error.localizedDescription)")
        }
        alarm?.numberOfLoops = -1
        volumeView.setVolume(1.0)
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
            let circleRenderer = MKCircleRenderer(overlay: overlay)
            circleRenderer.fillColor = UIColor.blue.withAlphaComponent(0.1)
            circleRenderer.strokeColor = UIColor.blue
            circleRenderer.lineWidth = 1

            return circleRenderer
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
