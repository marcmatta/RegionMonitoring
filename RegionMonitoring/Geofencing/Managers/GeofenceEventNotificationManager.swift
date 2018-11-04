//
//  GeofenceEventNotificationManager.swift
//  RegionMonitoring
//
//  Created by Mymac on 11/4/18.
//  Copyright © 2018 marxmatta. All rights reserved.
//

import Foundation
import UserNotifications
import CoreData

func Translate(_ key: String) -> String {
    return key
}

class GeofenceEventNotificationManager: NSObject {
    static let shared = GeofenceEventNotificationManager()
    lazy var controller : NSFetchedResultsController<CDGeofenceEvent> = {
        let fetchRequest: NSFetchRequest<CDGeofenceEvent> = CDGeofenceEvent.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        let controller = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: GeofencingStack.shared.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        controller.delegate = self
        return controller
    }()
    
    private override init() {
        super.init()
        
        self.prepareNotificationCategories()
    }

    func load() {
        try? controller.performFetch()
        
    }
    
    struct NotificationCategory {
        static let notifyEntryCategory = "notify_geofence_entry"
        static let notifyExitCategory = "notify_geofence_exit"
        static let notifyCheckoutCategory = "notify_geofence_checkout"
        static let notifyLastReminderCategory = "notify_geofence_maxPeriod"
        static let notifyCheckedOutCategory = "notify_geofence_checked_out"
    }
    
    struct NotificationAction {
        static let customizeEntry = "customize_geofence_entry"
        static let notifyEntry = "notify_geofence_entry"
        static let customizeExit = "customize_geofence_exit"
        static let notifyExit = "notify_geofence_exit"
        static let notifySupport = "notify_geofence_Support"
    }
    //MARK: Notifications -
    
    private func prepareNotificationCategories() {
        let customizeCheckinAction = UNNotificationAction(identifier: NotificationAction.customizeEntry, title: Translate("geofence_notification_action_customize_checkin"), options: .foreground)
        
        let checkinAction = UNNotificationAction(identifier: NotificationAction.notifyEntry,
                                                 title: Translate("geofence_notification_action_checkin"),
                                                 options: .foreground)
        
        let customizeCheckoutAction = UNNotificationAction(identifier: NotificationAction.customizeExit, title: Translate("geofence_notification_action_customize_checkout"), options: .foreground)
        
        let exitAction = UNNotificationAction(identifier: NotificationAction.notifyExit,
                                              title: Translate("geofence_notification_action_checkout"),
                                              options: .foreground)
        
        let supportAction = UNNotificationAction(identifier: NotificationAction.notifySupport,
                                                 title: Translate("geofence_notification_action_contact_support"),
                                                 options: .foreground)
        
        /////////
        
        let entryCategory = UNNotificationCategory(identifier: NotificationCategory.notifyEntryCategory,
                                                   actions: [customizeCheckinAction, checkinAction],
                                                   intentIdentifiers: [],
                                                   options: UNNotificationCategoryOptions.customDismissAction)
        
        /////////
        
        
        let exitCategory = UNNotificationCategory(identifier: NotificationCategory.notifyExitCategory,
                                                  actions: [customizeCheckoutAction, exitAction],
                                                  intentIdentifiers: [],
                                                  options: UNNotificationCategoryOptions.customDismissAction)
        ////////
        
        let checkoutCategory = UNNotificationCategory(identifier: NotificationCategory.notifyCheckoutCategory,
                                                      actions: [exitAction],
                                                      intentIdentifiers: [],
                                                      options: UNNotificationCategoryOptions.customDismissAction)
        
        /////////
        
        
        let maxPeriodCategory = UNNotificationCategory(identifier: NotificationCategory.notifyLastReminderCategory,
                                                       actions: [exitAction],
                                                       intentIdentifiers: [],
                                                       options: UNNotificationCategoryOptions.customDismissAction)
        ////////
        
        let checkedOutCategory = UNNotificationCategory(identifier: NotificationCategory.notifyCheckedOutCategory, actions: [supportAction], intentIdentifiers: [], options: UNNotificationCategoryOptions.customDismissAction)
        
        // Register the notification categories.
        let center = UNUserNotificationCenter.current()
        center.setNotificationCategories([entryCategory, exitCategory, checkoutCategory, maxPeriodCategory, checkedOutCategory])
    }
    
    func removeNotifications(forGeofenceEvent event: CDGeofenceEvent) {
        print(#function)
        
        UNUserNotificationCenter.current().getPendingNotificationRequests { (requests) in
            let scheduledIds = requests.filter{$0.isNotificationRequestFor(geofenceWithIdentifier: event.geofence!.identifier!)}.map{ $0.identifier }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: scheduledIds)
        }
        
        let identifiers = [NotificationCategory.notifyEntryCategory, NotificationCategory.notifyExitCategory].map {event.notificationIdentifier(using: $0)}
        
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiers)
    }
    
    func rescheduleMaxPeriodNotification(forGeofenceWithIdentifier identifier: String, withTimeDifference difference: Double) {
        print(#function)
        
        UNUserNotificationCenter.current().getPendingNotificationRequests { (requests) in
            let requestIdentifier = requests.first(where: { (request) -> Bool in
                if request.content.categoryIdentifier == NotificationCategory.notifyLastReminderCategory, request.isNotificationRequestFor(geofenceWithIdentifier: identifier) {
                    return true
                }
                
                return false
            })?.identifier
            
            guard let identifier = requestIdentifier else {
                return
            }
            
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        }
    }
    
    func presentEntryNotificationIfPossible(forGeofenceEventWithIdentifier identifier: String) {
        let context = GeofencingStack.shared.newBackgroundContext()
        guard let geofenceEvent = GeofencingCoreDataRepository.geofenceEvent(with: identifier, context: context), geofenceEvent.type == GeofenceEventType.entry.rawValue else {
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = NSString.localizedUserNotificationString(forKey: "default_msg_title", arguments: nil)
        content.body = NSString.localizedUserNotificationString(forKey: "geofence_notification_entry", arguments: nil)
        content.sound = UNNotificationSound.default
        content.categoryIdentifier = NotificationCategory.notifyEntryCategory
        content.userInfo = geofenceEvent.notificationUserInfo
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: geofenceEvent.notificationIdentifier(using: NotificationCategory.notifyEntryCategory), content: content, trigger: trigger)
        
        let center = UNUserNotificationCenter.current()
        center.add(request)
    }
    
    func presentExitNotificationIfPossible(forGeofenceEventWithIdentifier identifier: String) {
        let context = GeofencingStack.shared.newBackgroundContext()
        guard let geofenceEvent = GeofencingCoreDataRepository.geofenceEvent(with: identifier, context: context), geofenceEvent.type == GeofenceEventType.exit.rawValue else {
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = NSString.localizedUserNotificationString(forKey: "default_msg_title", arguments: nil)
        content.body = NSString.localizedUserNotificationString(forKey: "geofence_notification_exit", arguments: nil)
        content.sound = UNNotificationSound.default
        content.categoryIdentifier = NotificationCategory.notifyExitCategory
        content.userInfo = geofenceEvent.notificationUserInfo
        
        let trigger = UNTimeIntervalNotificationTrigger.init(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest.init(identifier: geofenceEvent.notificationIdentifier(using: NotificationCategory.notifyExitCategory), content: content, trigger: trigger)
        
        let center = UNUserNotificationCenter.current()
        center.add(request)
    }
    
    func hasTimesheetScheduledEventsfor(geofenceEventWithIdentifier identifier: String) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var hasRequests = false
        
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            hasRequests = requests.filter({ (request) -> Bool in
                return request.isNotificationRequestFor(geofenceWithIdentifier: identifier)
            }).count > 0
            
            semaphore.signal()
        }
        
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        
        return hasRequests
    }
    
    
    
    //    internal func scheduleExpectedCheckoutNotification(for timesheetEvent: TimesheetEvent) -> Observable<Void>{
    //        print(#function)
    //
    //        return self.repository
    //            .geofence(with: timesheetEvent.geofenceId)
    //            .unwrap()
    //            .flatMapLatest({ geofence -> Observable<Void> in
    //                let content = UNMutableNotificationContent()
    //                content.title = NSString.localizedUserNotificationString(forKey: "default_msg_title", arguments: nil)
    //                content.body = NSString.localizedUserNotificationString(forKey: "geofence_notification_checkout_reminder1", arguments: nil)
    //                content.sound = UNNotificationSound.default()
    //                content.categoryIdentifier = NotificationCategory.notifyCheckoutCategory
    //                content.userInfo = timesheetEvent.notificationUserInfo
    //
    //                let trigger = UNTimeIntervalNotificationTrigger.init(timeInterval: geofence.expectedCheckout * 3600, repeats: false)
    //                let request = UNNotificationRequest.init(identifier:  timesheetEvent.notificationIdentifier(using: NotificationCategory.notifyCheckoutCategory), content: content, trigger: trigger)
    //
    //                let center = UNUserNotificationCenter.current()
    //                center.add(request)
    //                return Observable.just(())
    //            })
    //    }
    //
    //    internal func scheduleMaxPeriodNotification(for timesheetEvent: TimesheetEvent) -> Observable<Void> {
    //        print(#function)
    //
    //        return self.repository
    //            .geofence(with: timesheetEvent.geofenceId)
    //            .unwrap()
    //            .flatMapLatest({ geofence -> Observable<Void> in
    //                let content = UNMutableNotificationContent()
    //                content.title = NSString.localizedUserNotificationString(forKey: "default_msg_title", arguments: nil)
    //                content.body = NSString.localizedUserNotificationString(forKey: "geofence_notification_checkout_reminder2", arguments: nil)
    //                content.sound = UNNotificationSound.default()
    //                content.categoryIdentifier = NotificationCategory.notifyLastReminderCategory
    //                content.userInfo = timesheetEvent.notificationUserInfo
    //
    //                let trigger = UNTimeIntervalNotificationTrigger.init(timeInterval: geofence.maxPeriodToCheckout * 3600, repeats: false)
    //                let request = UNNotificationRequest.init(identifier: timesheetEvent.notificationIdentifier(using: NotificationCategory.notifyLastReminderCategory), content: content, trigger: trigger)
    //
    //                let center = UNUserNotificationCenter.current()
    //                center.add(request)
    //                return Observable.just(())
    //            })
    //    }
    //
    //    internal func scheduleLocalNotifications(for timesheetEvent: TimesheetEvent) -> Observable<Void>{
    //        print(#function)
    //        return self.scheduleMaxPeriodNotification(for: timesheetEvent)
    //            .flatMapLatest {self.scheduleExpectedCheckoutNotification(for: timesheetEvent)}
    //    }
    
}

extension UNNotificationRequest {
    func isNotificationRequestFor(geofenceWithIdentifier identifier: String) -> Bool{
        if let geofenceId = self.content.userInfo["geofenceId"] as? String, geofenceId == identifier {
            return true
        }
        
        return false
    }
}

extension CDGeofenceEvent {
    var notificationUserInfo: [AnyHashable: Any] {
        return ["geofenceId": self.geofence!.identifier!,
                "geofenceEventId": self.eventId!]
    }
    
    func notificationIdentifier(using category: String) -> String{
        return "\(category)-\(eventId!)"
    }
}

//extension TimesheetEvent {
//    var notificationUserInfo: [AnyHashable: Any] {
//        return ["geofenceId": self.geofenceId,
//                "geofenceEventId": self.eventId]
//    }
//
//    func notificationIdentifier(using category: String) -> String{
//        return "\(category)-\(eventId)"
//    }
//}


extension GeofenceEventNotificationManager: NSFetchedResultsControllerDelegate {
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        if let object = anObject as? CDGeofenceEvent {
            switch type {
            case .insert:
                if let type = GeofenceEventType(rawValue: object.type!) {
                    switch type {
                    case .entry:
                        presentEntryNotificationIfPossible(forGeofenceEventWithIdentifier: object.eventId!)
                    case .exit:
                        presentExitNotificationIfPossible(forGeofenceEventWithIdentifier: object.eventId!)
                    default:
                        break
                    }
                }
            case .delete:
                removeNotifications(forGeofenceEvent: object)
            default:
                break
            }
        }
    }
}
