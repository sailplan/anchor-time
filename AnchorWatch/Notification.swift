import Foundation

extension Notification.Name {
    static let didChangeState = Notification.Name("didChanngeState")
    static let volumeDidChange = Notification.Name(rawValue: "AVSystemController_SystemVolumeDidChangeNotification")
}
