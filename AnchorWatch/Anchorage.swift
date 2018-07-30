import MapKit

class Anchorage: NSObject {
    let coordinate: CLLocationCoordinate2D
    let circle: MKCircle
    
    var region: MKCoordinateRegion {
        get {
            let distance = (circle.radius * 2) * 1.2
            return MKCoordinateRegionMakeWithDistance(coordinate, distance, distance)
        }
    }
    
    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        self.circle = MKCircle(center: coordinate, radius: 200)
    }
}
