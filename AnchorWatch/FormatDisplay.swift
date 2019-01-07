import Foundation

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
}
