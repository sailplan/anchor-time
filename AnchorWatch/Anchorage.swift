import MapKit

class Anchorage: NSObject, NSCoding, MKAnnotation {
    enum State: Int {
        case dropped
        case set
        case dragging
    }

    var state: State = .dropped {
        didSet(oldValue) {
            print("Changing anchorage state", oldValue, self.state)
            NotificationCenter.default.post(name: .didChangeState, object: self)
        }
    }

    @objc dynamic var coordinate: CLLocationCoordinate2D
    var radius: CLLocationDistance = 0
    var locations: [CLLocation] = []
    let identifier = "anchorage"

    /// The location of the anchorage as a CLLocation
    var location: CLLocation {
        return CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    /// The anchorage as a CLCircularRegion
    var fence: CLCircularRegion {
        return CLCircularRegion(center: coordinate, radius: radius, identifier: "anchorage")
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

    func check(_ location: CLLocation) {
        if !contains(location) {
            self.state = .dragging
        }
    }

    /// Widen the anchorage radius to include the given location, including any GPS innacuracy
    func widen(_ location: CLLocation) {
        radius = max(radius, distanceTo(location) + location.horizontalAccuracy)
        save()
    }

    func track(_ location: CLLocation) {
        self.locations.append(location)
    }

    /// Get the distance from the anchor to another location
    func distanceTo(_ otherLocation: CLLocation) -> CLLocationDistance {
        return location.distance(from: otherLocation)
    }

    func bearingFrom(_ otherLocation: CLLocationCoordinate2D) -> Double {
        // get lat/lon in radians
        let lat1 = otherLocation.latitude * .pi / 180.0
        let lon1 = otherLocation.longitude * .pi / 180.0
        let lat2 = self.coordinate.latitude * .pi / 180.0
        let lon2 = self.coordinate.longitude * .pi / 180.0
        let dLon = lon2 - lon1

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing = atan2(y, x) * 180.0 / .pi

        if (bearing >= 0) {
            return bearing
        } else {
            return 360.0 + bearing
        }
    }

    /// Set the anchor and save the anchorage
    func set() {
        self.state = .set
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
        state = State(rawValue: decoder.decodeInteger(forKey: "state"))!
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(coordinate.latitude, forKey: "latitude")
        coder.encode(coordinate.longitude, forKey: "longitude")
        coder.encode(radius, forKey: "radius")
        coder.encode(state.rawValue, forKey: "state")
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
