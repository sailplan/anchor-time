import MapKit

class Anchorage: NSObject, NSCoding, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    var radius: CLLocationDistance = 0
    var isSet: Bool = false
    let identifier = "anchorage"

    var circle: MKCircle {
        get {
            return MKCircle(center: coordinate, radius: radius)
        }
    }
    
    var region: MKCoordinateRegion {
        get {
            let distance = (radius * 2) * 1.2
            return MKCoordinateRegion.init(center: coordinate, latitudinalMeters: distance, longitudinalMeters: distance)
        }
    }
    
    var fence: CLCircularRegion {
        get {
            let region = CLCircularRegion(center: coordinate, radius: radius, identifier: "anchorage")
            region.notifyOnEntry = false
            region.notifyOnExit = true
            return region

        }
    }
    
    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        super.init()
        self.save()
    }
    
    func widen(_ location: CLLocation) {
        radius = max(radius, distanceTo(location))
        save()
    }
    
    func distanceTo(_ location: CLLocation) -> CLLocationDistance {
        let from = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return location.distance(from: from)
    }

    func set() {
        self.isSet = true
        save()
    }
    
    func contains(_ location: CLLocation) -> Bool {
        return fence.contains(location.coordinate)
    }
    
    // MARK: NSCoding
    
    required init?(coder decoder: NSCoder) {
        let latitude = decoder.decodeDouble(forKey: "latitude")
        let longitude = decoder.decodeDouble(forKey: "longitude")
        coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        radius = decoder.decodeDouble(forKey: "radius")
        isSet = decoder.decodeBool(forKey: "isSet")
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(coordinate.latitude, forKey: "latitude")
        coder.encode(coordinate.longitude, forKey: "longitude")
        coder.encode(radius, forKey: "radius")
        
        coder.encode(isSet, forKey: "isSet")
    }
    
    // Mark: Persistance
    
    func save() {
        let data = NSKeyedArchiver.archivedData(withRootObject: self)
        print("Saving", data)
        UserDefaults.standard.set(data, forKey: "anchorage")
    }

    func clear() {
        print("Clearing")
        UserDefaults.standard.removeObject(forKey: "anchorage")
    }

    class func find() -> Anchorage? {
        guard let data = UserDefaults.standard.data(forKey: "anchorage") else { return nil }
        guard let anchorage = NSKeyedUnarchiver.unarchiveObject(with: data) as? Anchorage else { return nil }
        return anchorage
    }
}
