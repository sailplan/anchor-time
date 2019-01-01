import Foundation

struct FormatDisplay {
    static func distance(_ meters: Double, unit: UnitLength = .feet) -> String {
        let distance = Measurement<UnitLength>(value: meters, unit: .meters).converted(to: unit)
        
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .providedUnit
        formatter.numberFormatter.maximumFractionDigits = meters <= 3 ? 1 : 0

        return formatter.string(from: distance)
    }
}
