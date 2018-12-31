//
//  ViewController.swift
//  AnchorWatch
//
//  Created by Brandon Keepers on 7/29/18.
//  Copyright © 2018 Brandon Keepers. All rights reserved.
//

import UIKit
import MapKit
import UserNotifications
import AVFoundation

class ViewController: UIViewController {
    //MARK: - Properties
    let locationManager = CLLocationManager()
    let notificationCenter = UNUserNotificationCenter.current()
    var alarm: AVAudioPlayer?

    var anchorage: Anchorage?
    var circle: MKCircle?

    //MARK: - Outlets
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var dropAnchorButton: UIView!
    @IBOutlet weak var setAnchorButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!

    var notificationContent: UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.body = "Your anchor is dragging!"
        content.sound = UNNotificationSound.defaultCriticalSound(withAudioVolume: 1.0)
        return content
    }

    //MARK: - Life cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        if !CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) {
            showAlert(withTitle:"Error", message: "Location monitoring is not supported on this device!")
            return
        }

        if CLLocationManager.authorizationStatus() != .authorizedAlways {
            showAlert(withTitle:"Warning", message: "You must allow permission to always uswe location.")
        }

        mapView.delegate = self

        locationManager.delegate = self
        locationManager.requestAlwaysAuthorization()
        locationManager.activityType = .other
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.startUpdatingLocation()

        NotificationCenter.default.addObserver(self, selector: #selector(didChangeState(_:)), name: .didChangeState, object: nil)

        self.anchorage = Anchorage.load()
        renderAnchorage()
        updateUI()
        setupAlarm()
    }

    //MARK: - App logic

    @objc func didChangeState(_ notification:Notification) {
        switch anchorage!.state {
        case .dragging:
            activateAlarm()
        default:
            print("Anchorage state changed", anchorage!.state)
            // no worries
        }
    }
    
    @IBAction func dropAnchor(_ sender: Any) {
        guard let location = locationManager.location else { return }
        anchorage = Anchorage(coordinate: location.coordinate)

        print("Anchor dropped", anchorage!.coordinate)

        renderAnchorage()
        updateUI()
    }
    
    @IBAction func setAnchor(_ sender: Any) {
        guard let anchorage = self.anchorage else { return }
        anchorage.set()
        print("Anchor set", anchorage.coordinate, anchorage.radius)

        let fence = anchorage.fence
        locationManager.startMonitoring(for: fence)
        createNotification(fence)

        updateUI()
    }

    func createNotification(_ fence: CLCircularRegion) {
        let trigger = UNLocationNotificationTrigger(region: fence, repeats: true)
        let request = UNNotificationRequest(identifier: "dragging",
                                            content: notificationContent,
                                            trigger: trigger)

        notificationCenter.add(request) { error in
            if let error = error {
                print("Error: \(error)")
            }
        }
    }

    func createTestNotification() {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        let request = UNNotificationRequest(identifier: "test", content: notificationContent, trigger: trigger)

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

        // Stop location monitoring
        locationManager.monitoredRegions.forEach {
            locationManager.stopMonitoring(for: $0)
        }
        notificationCenter.removeAllPendingNotificationRequests()

        // Reset Model
        anchorage.clear()
        self.anchorage = nil

        stopAlarm()
        updateUI()
    }
    
    func renderAnchorage() {
        guard let anchorage = self.anchorage else { return }
        
        // Add anchorage to the map
        mapView.addAnnotation(anchorage)
        
        renderCircle()
    }
    
    func renderCircle() {
        if (circle != nil) {
            mapView.removeOverlay(circle!)
        }
        
        circle = anchorage!.circle
        mapView.addOverlay(circle!)

        // Center map on anchorage
        mapView.setRegion(anchorage!.region, animated: true)
    }
    
    func updateLocation(location: CLLocation) {
        guard let anchorage = self.anchorage else { return }

        if let lastLocation = anchorage.locations.last {
            let coordinates = [lastLocation.coordinate, location.coordinate]
            mapView.addOverlay(MKPolyline(coordinates: coordinates, count: 2))
        }

        switch anchorage.state {
        case .dropped:
            anchorage.widen(location)
            renderCircle()
        case .set:
            anchorage.check(location)
            // TODO: Track location
        case .dragging:
            // TODO: already dragging
            break
        }
    }
    
    func updateUI() {
        self.dropAnchorButton.isHidden = anchorage != nil
        self.setAnchorButton.isHidden = anchorage == nil || anchorage!.state != .dropped
        self.cancelButton.isHidden = anchorage == nil
        
        if(anchorage == nil) {
            // Start following user's current location
            mapView.setUserTrackingMode(MKUserTrackingMode.follow, animated: true)
            mapView.isZoomEnabled = true
        } else {
            // Stop following user's current location
            mapView.setUserTrackingMode(MKUserTrackingMode.none, animated: true)
            mapView.isZoomEnabled = true
        }
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
        let fileURL = Bundle.main.path(forResource: "shipbell", ofType: "mp3")
        do {
            alarm = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: fileURL!))
        } catch let error {
            print("Can't play the audio file failed with an error \(error.localizedDescription)")
        }
        alarm?.numberOfLoops = -1
    }
    
}

//MARK: - Core Location
extension ViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("Location Manager - didChangeAuthorization", status)
        mapView.showsUserLocation = (status == .authorizedAlways)
    }

    func locationManager(_ manager: CLLocationManager,  didUpdateLocations locations: [CLLocation]) {
        updateLocation(location: locations.last!)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let error = error as? CLError, error.code == .denied {
            // Location updates are not authorized.
            manager.stopUpdatingLocation()
            return
        }
        // TODO: Notify the user of any errors.
        print("Location Manager failed with the following error:", error, error.localizedDescription)
    }
}

//MARK: - MapKit
extension ViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        var view : MKPinAnnotationView
        guard let annotation = annotation as? Anchorage else { return nil }
        if let dequeuedView = mapView.dequeueReusableAnnotationView(withIdentifier: annotation.identifier) as? MKPinAnnotationView {
            view = dequeuedView
        } else { // make a new view
            view = MKPinAnnotationView(annotation: annotation, reuseIdentifier: annotation.identifier)
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
