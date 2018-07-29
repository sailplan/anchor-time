//
//  ViewController.swift
//  AnchorWatch
//
//  Created by Brandon Keepers on 7/29/18.
//  Copyright © 2018 Brandon Keepers. All rights reserved.
//

import UIKit
import MapKit

let anchorCoordinate = CLLocationCoordinate2DMake(45.23230, -85.08603)

class ViewController: UIViewController, MKMapViewDelegate {
    //MARK: Properties and Outlets
    @IBOutlet weak var mapView: MKMapView!

    
    //MARK: - Annotations
    
    //MARK: - Overlays
    
    //MARK: - Map setup
    func resetRegion(){
        let region = MKCoordinateRegionMakeWithDistance(anchorCoordinate, 1000, 1000)
        mapView.setRegion(region, animated: true)
    }
    
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

    //Mark: Life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        resetRegion()
        mapView.delegate = self
        mapView.addAnnotation(AnchorLocation(position: anchorCoordinate))
        mapView.add(MKCircle(center: anchorCoordinate, radius: 1000))
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
}

