import MapKit

class Anchorage: NSObject {
    let coordinate: CLLocationCoordinate2D
    var radius: Double = 0
    var isSet: Bool = false
    
    var circle: MKCircle {
        get {
            return MKCircle(center: coordinate, radius: radius)
        }
    }
    
    var region: MKCoordinateRegion {
        get {
            let distance = (radius * 2) * 1.2
            return MKCoordinateRegionMakeWithDistance(coordinate, distance, distance)
        }
    }
    
    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }
    
    func set() {
        self.isSet = true
    }
}
