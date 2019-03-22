import os.log
import UIKit
import CoreLocation
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    let notificationCenter = UNUserNotificationCenter.current()
    let locationManager = CLLocationManager()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        locationManager.delegate = self
        locationManager.requestAlwaysAuthorization()
        
        notificationCenter.delegate = self
        notificationCenter.requestAuthorization(options: [.sound, .alert, .criticalAlert]) { success, error in
                if let error = error {
                    os_log("%@", log: .lifecycle, type: .error, error.localizedDescription)
                }
        }

        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        os_log("App will resign to inactive state", log: .lifecycle, type: .debug)
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        os_log("App entered background state", log: .lifecycle, type: .debug)
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        os_log("App will enter foreground state", log: .lifecycle, type: .debug)
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        os_log("App entered active state", log: .lifecycle, type: .debug)
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        os_log("App will terminate", log: .lifecycle, type: .debug)
    }

    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        os_log("App received memory warning", log: .lifecycle, type: .debug)
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler:
        @escaping () -> Void) {
        os_log("Receiving notification in background: %@", log: .lifecycle, type: .debug, response.notification)

        completionHandler()
    }
    
    // Receive local notification when app in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {

        os_log("Receiving notification in foreground", log: .lifecycle, type: .debug, notification)
        completionHandler([.alert, .sound]) // Display notification as regular alert and play sound
    }
}

extension AppDelegate: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        let log = "Location Manager - didChangeAuthorization: \(status.rawValue)"
        os_log("%@", log: .location, type: .debug, log)

        switch status {
        case .authorizedAlways:
            // This is what was expected.
            break
        case .notDetermined:
            manager.requestAlwaysAuthorization()
        case .authorizedWhenInUse, .restricted, .denied:
            let alertController = UIAlertController(
                title: "Background Location Access Disabled",
                message: "Background location access must be allowed to use this app. Open settings and set location access to 'Always'.",
                preferredStyle: .alert)
            
            let openAction = UIAlertAction(title: "Open Settings", style: .default) { (action) in
                if let url = URL(string:UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url, options: [:])
                }
            }
            alertController.addAction(openAction)
            
            self.window!.rootViewController!.present(alertController, animated: true, completion: nil)
            
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        os_log("Location Manager  - didFailWithError", log: .location, type: .error, error.localizedDescription)
    }

    func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        os_log("Location Manager - didPauseLocationUpdates", log: .location, type: .debug)
    }
    
    func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager) {
        os_log("Location Manager - didResumeLocationUpdates", log: .location, type: .debug)
    }
}
