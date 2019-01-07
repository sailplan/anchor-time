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
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
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
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
//        application.applicationIconBadgeNumber = 0
//        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
//        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
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
