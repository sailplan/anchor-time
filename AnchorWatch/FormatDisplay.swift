import Foundation
import CoreLocation

struct FormatDisplay {
    static let isMetric = Locale.current.usesMetricSystem

    static func distance(_ meters: Double) -> String {
        let unit: UnitLength = isMetric ? .meters : .feet
        let distance = Measurement<UnitLength>(value: meters, unit: .meters).converted(to: unit)

        let formatter = MeasurementFormatter()
        formatter.unitOptions = .providedUnit
        formatter.numberFormatter.maximumFractionDigits = meters <= 3 ? 1 : 0

        return formatter.string(from: distance)
    }

    static func degrees(_ degrees: Double) -> String {
        return String(format: "%dº", Int(round(degrees)))
    }

    static func coordinate(_ coordinate: CLLocationCoordinate2D) -> String {
        let latDegrees = floor(abs(coordinate.latitude))
        let latMinutes = 60 * (abs(coordinate.latitude) - latDegrees)

        let longDegrees = floor(abs(coordinate.longitude))
        let longMinutes = 60 * (abs(coordinate.longitude) - longDegrees)

        return String(
            format: "%d°%.3f'%@  %d°%.3f'%@",
            Int(latDegrees), latMinutes, latDegrees >= 0 ? "N" : "S",
            Int(longDegrees), longMinutes, longDegrees >= 0 ? "E" : "W"
        )
    }
}
