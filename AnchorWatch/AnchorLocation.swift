import UIKit
import MapKit

class AnchorLocation: NSObject, MKAnnotation {
    var identifier = "anchor"
    var title: String? = "Current anchor position"
    var coordinate: CLLocationCoordinate2D
    
    init(position:CLLocationCoordinate2D) {
        coordinate = position
    }
}
