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

class ViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {
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
    
    //MARK: - App logic
    
    @IBAction func dropAnchor(_ sender: Any) {
        guard let location = locationManager.location else { return }
        anchorage = Anchorage(coordinate: location.coordinate)
        renderAnchorage()
        updateUI()
    }
    
    @IBAction func setAnchor(_ sender: Any) {
        guard let anchorage = self.anchorage else { return }
        anchorage.set()
        
        let fence = anchorage.fence
        
        let authorized = CLLocationManager.authorizationStatus() == .authorizedAlways
        let available = CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self)
        
        if authorized && available {
            locationManager.startMonitoring(for: fence)
            print("Monitoring location!", fence)
            
            let notificationContent = UNMutableNotificationContent()
            notificationContent.body = "OMG you're dragging anchor!"
            
            if #available(iOS 12.0, *) {
                notificationContent.sound = UNNotificationSound.defaultCriticalSound(withAudioVolume: 1.0)
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

        } else {
            print("Monitoring not available!")
        }
        
        updateUI()
    }
    
    @IBAction func cancel(_ sender: Any) {
        mapView.removeAnnotation(anchorage!)
        
        if(circle != nil) {
            mapView.removeOverlay(circle!)
        }
        
        locationManager.stopMonitoring(for: anchorage!.fence)
        notificationCenter.removeAllPendingNotificationRequests()

        self.anchorage = nil
        self.circle = nil
        
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
            // Stop following user's current location
            mapView.setUserTrackingMode(MKUserTrackingMode.follow, animated: true)
            mapView.isZoomEnabled = true
        } else {
            // Stop following user's current location
            mapView.setUserTrackingMode(MKUserTrackingMode.none, animated: true)
            mapView.isZoomEnabled = true
        }
    }
    
    //MARK: - MapKit
    
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
    
    //MARK: - Core Location
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
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
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?,
                         withError error: Error) {
        print("Monitoring failed for region with identifier: \(region!.identifier)")
    }
    
    //MARK: - Life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        mapView.delegate = self
        
        locationManager.delegate = self
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
        
        self.anchorage = Anchorage.find()
        renderAnchorage()
        updateUI()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func showAlert(withTitle title: String?, message: String?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .cancel, handler: nil)
        alert.addAction(action)
        present(alert, animated: true, completion: nil)
    }
    
}

