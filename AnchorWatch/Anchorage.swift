import MapKit

class Anchorage: NSObject, NSCoding, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    var radius: CLLocationDistance = 0
    var isSet: Bool = false
    let identifier = "anchorage"

    /// The location of the anchorage as a CLLocation
    var location: CLLocation {
        return CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    /// The anchorage as a CLCircularRegion
    var fence: CLCircularRegion {
        let region = CLCircularRegion(center: coordinate, radius: radius, identifier: "anchorage")
        region.notifyOnEntry = true
        region.notifyOnExit = true
        return region
    }

    /// The anchorage as a MKCircle
    var circle: MKCircle {
        return MKCircle(center: coordinate, radius: radius)
    }

    /// The anchorage as a MKCoordinateRegion
    var region: MKCoordinateRegion {
        let distance = (radius * 2) * 1.2
        return MKCoordinateRegion.init(center: coordinate, latitudinalMeters: distance, longitudinalMeters: distance)
    }
    
    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        super.init()
        self.save()
    }

    /// Widen the anchorage radius to include the given location, including any GPS innacuracy
    func widen(_ location: CLLocation) {
        radius = max(radius, distanceTo(location) + location.horizontalAccuracy)
        save()
    }

    /// Get the distance from the anchor to another location
    func distanceTo(_ otherLocation: CLLocation) -> CLLocationDistance {
        return location.distance(from: otherLocation)
    }

    /// Set the anchor and save the anchorage
    func set() {
        self.isSet = true
        save()
    }

    /// Returns true if the given location is included in the anchorage
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

    /// Persist the current anchorage
    func save() {
        let data = NSKeyedArchiver.archivedData(withRootObject: self)
        UserDefaults.standard.set(data, forKey: "anchorage")
    }

    /// Clear any saved anchorage
    func clear() {
        UserDefaults.standard.removeObject(forKey: "anchorage")
    }

    /// Load the saved anchorage
    class func load() -> Anchorage? {
        guard let data = UserDefaults.standard.data(forKey: "anchorage") else { return nil }
        guard let anchorage = NSKeyedUnarchiver.unarchiveObject(with: data) as? Anchorage else { return nil }
        return anchorage
    }
}
