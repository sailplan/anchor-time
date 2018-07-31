//
//  ViewController.swift
//  AnchorWatch
//
//  Created by Brandon Keepers on 7/29/18.
//  Copyright © 2018 Brandon Keepers. All rights reserved.
//

import UIKit
import MapKit

class ViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {
    //MARK: - Properties
    let locationManager = CLLocationManager()
    var lastLocation: CLLocation?
    
    var anchorage: Anchorage?
    var circle: MKCircle?

    //MARK: - Outlets
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var dropAnchorButton: UIButton!
    
    //MARK: - App logic
    
    @IBAction func dropAnchor(_ sender: Any) {
        if(anchorage == nil) {
            anchorage = Anchorage(coordinate: lastLocation!.coordinate)
            renderAnchorage()
        } else {
            setAnchor()
        }
    }
    
    func setAnchor() {
        guard let anchorage = self.anchorage else { return }
        anchorage.set()
        
        let fence = anchorage.fence
        if CLLocationManager.isMonitoringAvailable(for: fence.classForCoder) {
            locationManager.startMonitoring(for: fence)
            
            print("Monitoring location!", fence)
        } else {
            print("Monitoring not available!")
        }
        
        dropAnchorButton.isHidden = true
    }
    
    func renderAnchorage() {
        guard let anchorage = self.anchorage else { return }
        
        // Add anchorage to the map
        mapView.addAnnotation(anchorage)
        
        // Stop following user's current location
        mapView.setUserTrackingMode(MKUserTrackingMode.none, animated: true)
        
        dropAnchorButton.setTitle("Set Anchor", for: .normal)
        
        renderCircle()
        
        if(anchorage.isSet) {
            dropAnchorButton.isHidden = true
        }
    }
    
    func renderCircle() {
        if (circle != nil) {
            mapView.remove(circle!)
        }
        
        circle = anchorage!.circle
        mapView.add(circle!)

        // Center map on anchorage
        mapView.setRegion(anchorage!.region, animated: true)
    }
    
    func updateLocation(location: CLLocation) {
        lastLocation = location
        
        if(anchorage == nil) {
            return
        }
        
        if(anchorage!.isSet) {
            // TODO: Track location

            if(!anchorage!.contains(location)) {
                showAlert(withTitle: "Dragging!", message: "OMG you're dragging!")
            }
        } else {
            anchorage!.widen(location)
            renderCircle()
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
        print("Location Manager failed with the following error: \(error)")
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?,
                         withError error: Error) {
        print("Monitoring failed for region with identifier: \(region!.identifier)")
    }
    
    //MARK: - Life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // TODO: remove once UI exists for canceling anchorage
        UserDefaults.standard.removeObject(forKey: "anchorage")
        
        mapView.delegate = self
        mapView.setUserTrackingMode(MKUserTrackingMode.follow, animated: true)
        
        locationManager.delegate = self
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
        
        self.anchorage = Anchorage.find()
        renderAnchorage()
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

