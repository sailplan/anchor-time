import Foundation
import os.log

extension OSLog {
    private static var subsystem = Bundle.main.bundleIdentifier!

    /// Logs lifecycle eventsx like viewDidLoad.
    static let app = OSLog(subsystem: subsystem, category: "app")
    static let lifecycle = OSLog(subsystem: subsystem, category: "lifecycle")
}
