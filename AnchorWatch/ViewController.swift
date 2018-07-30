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
            let anchorage = Anchorage(coordinate: lastLocation!.coordinate)

            // Add anchorage to the map
            mapView.addAnnotation(AnchorLocation(position: anchorage.coordinate))

            // Stop following user's current location
            mapView.setUserTrackingMode(MKUserTrackingMode.none, animated: true)
            
            self.anchorage = anchorage
            
            dropAnchorButton.setTitle("Set Anchor", for: .normal)
            
            renderCircle()
        } else {
            anchorage!.set()
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
        guard let annotation = annotation as? AnchorLocation else {return nil}
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
    }
    
    //MARK: - Life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
        mapView.setUserTrackingMode(MKUserTrackingMode.follow, animated: true)

        locationManager.delegate = self
        locationManager.requestAlwaysAuthorization()
        locationManager.delegate = self
        locationManager.startUpdatingLocation()
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

