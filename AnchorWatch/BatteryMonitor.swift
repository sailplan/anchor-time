import UIKit

protocol BatteryMonitorDelegate {
    func isBatteryMonitoringEnabled() -> Bool
    func batteryLow(level: Float)
    func batteryCritical(level: Float)
}

/// Convenience class for monitoring low battery
class BatteryMonitor {
    var delegate: BatteryMonitorDelegate?

    var level: Float {
        return UIDevice.current.batteryLevel
    }

    var state: UIDevice.BatteryState {
        return UIDevice.current.batteryState
    }

    var lowLevel : Float = 0.2
    var criticalLevel : Float = 0.1

    private var lowDelivered = false
    private var criticalDelivered = false

    init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        NotificationCenter.default.addObserver(self, selector: #selector(levelDidChange(_:)), name: UIDevice.batteryLevelDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(stateDidChange(_:)), name: UIDevice.batteryStateDidChangeNotification, object: nil)
    }

    @objc private func levelDidChange(_ notification:Notification) {
        guard (delegate?.isBatteryMonitoringEnabled() ?? false) else { return }

        // Do nothing if battery is charging or is not low
        if state == .charging || level > lowLevel {
            return
        }

        if level <= criticalLevel && !criticalDelivered {
            delegate?.batteryCritical(level: level)
            criticalDelivered = true
        } else if level <= lowLevel && !lowDelivered {
            delegate?.batteryLow(level: level)
            lowDelivered = true
        }
    }

    @objc private func stateDidChange(_ notification:Notification) {
        // Reset delivery state once the device is plugged in
        if state == .charging {
            // Reset delivery state
            lowDelivered = false
            criticalDelivered = false
        }
    }
}
