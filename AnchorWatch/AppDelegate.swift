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
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("Receiving notification", notification)
        // Process notification content

        completionHandler([.alert, .sound]) // Display notification as regular alert and play sound
    }
}

extension AppDelegate: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        print("Monitoring location", region)
    }

    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        switch state {
        case .inside:
            print("Inside region", region)
        case .outside:
            print("Outside region", region)
        case .unknown:
            print("Could not determine state for region", region)
        }

    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?,
                         withError error: Error) {
        print("Monitoring failed for region", region!)
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("Exiting region", region)
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("Entering region", region)
    }
}
