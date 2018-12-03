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

class ViewController: UIViewController {
    //MARK: - Properties
    let locationManager = CLLocationManager()
    let notificationCenter = UNUserNotificationCenter.current()
    
    var anchorage: Anchorage?
    var circle: MKCircle?

    //MARK: - Outlets
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var dropAnchorButton: UIView!
    @IBOutlet weak var setAnchorButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!


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

        self.anchorage = Anchorage.load()
        renderAnchorage()
        updateUI()
    }

    //MARK: - App logic
    
    @IBAction func dropAnchor(_ sender: Any) {
        guard let location = locationManager.location else { return }
        anchorage = Anchorage(coordinate: location.coordinate)
        print("Anchor dropped", anchorage!.coordinate)
        renderAnchorage()
        updateUI()
        locationManager.startUpdatingLocation()
    }
    
    @IBAction func setAnchor(_ sender: Any) {
        guard let anchorage = self.anchorage else { return }
        anchorage.set()
        print("Anchor set", anchorage.coordinate, anchorage.radius)

        let fence = anchorage.fence
        locationManager.startMonitoring(for: fence)

        let notificationContent = UNMutableNotificationContent()
        notificationContent.body = "OMG you're dragging anchor!"

        if #available(iOS 12.0, *) {
             UNNotificationSound.defaultCriticalSound(withAudioVolume: 1.0)
        } else {
            notificationContent.sound = UNNotificationSound.default
        }

        let trigger = UNLocationNotificationTrigger(region: fence, repeats: true)

        let request = UNNotificationRequest(identifier: "dragging",
                                            content: notificationContent,
                                            trigger: trigger)

        notificationCenter.add(request) { error in
            if let error = error {
                print("Error: \(error)")
            }
        }

        updateUI()
    }

    @IBAction func cancel(_ sender: Any) {
        guard let anchorage = self.anchorage else { return }

        locationManager.stopUpdatingLocation()

        // Remove map overlays
        mapView.removeAnnotation(anchorage)
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

        if(anchorage.isSet) {
            print("Current location", location)
            print("Anchor radius", anchorage.radius)
            print("Distance from anchor", anchorage.distanceTo(location))
            locationManager.requestState(for: anchorage.fence)
            // TODO: Track location
        } else {
            anchorage.widen(location)
            renderCircle()
        }
    }
    
    func updateUI() {
        self.dropAnchorButton.isHidden = anchorage != nil
        self.setAnchorButton.isHidden = anchorage == nil || anchorage!.isSet
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

    func showAlert(withTitle title: String?, message: String?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .cancel, handler: nil)
        alert.addAction(action)
        present(alert, animated: true, completion: nil)
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
        if overlay.isKind(of: MKCircle.self) {
            let circleRenderer = MKCircleRenderer(overlay: overlay)
            circleRenderer.fillColor = UIColor.blue.withAlphaComponent(0.1)
            circleRenderer.strokeColor = UIColor.blue
            circleRenderer.lineWidth = 1

            return circleRenderer
        }
        return MKOverlayRenderer(overlay: overlay)
    }
}
