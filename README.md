# RegionMonitoring
Simulated Loitering


## Requirements
1. Local Notifications
2. Location Always permissions

## Installation
1. Drop Geofencing folder into own code.
2. Code to start service

```swift

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey:  Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { (authorized, error) in
            print("location authorized")
        }
        
        GeofencingStack.shared.load {
            print("Core Data loaded")
        }
        
        GeofenceEventNotificationManager.shared.load()
        
        return true
  }
  ```
  ```swift
  extension AppDelegate : UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler(.alert)
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        print("\(response)")
        completionHandler()
    }
}
  ```
