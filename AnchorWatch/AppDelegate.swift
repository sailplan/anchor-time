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
                    print("Error: \(error)")
                }
        }

        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        print("App will resign to inactive state")
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        print("App entered background state")
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        print("App will enter foreground state")
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        print("App entered active state")
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        print("App will terminate")
    }

    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        print("App received memory warning")
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler:
        @escaping () -> Void) {
        print("Receiving notification in background", response.notification)

        completionHandler()
    }
    
    // Receive local notification when app in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {

        print("Receiving notification in foreground", notification)
        completionHandler([.alert, .sound]) // Display notification as regular alert and play sound
    }
}

extension AppDelegate: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("Location Manager - didChangeAuthorization", status)

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
        print("Location Manager  - didFailWithError:", error)
    }

    func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        print("Locastion Manager - didPauseLocationUpdates")
    }
    
    func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager) {
        print("Locastion Manager - didResumeLocationUpdates")
    }
}
