//
//  GeofencingLocationManagerDelegate.swift
//  RegionMonitoring
//
//  Created by Mymac on 11/2/18.
//  Copyright © 2018 marxmatta. All rights reserved.
//

import Foundation
import CoreLocation
import CoreData

class GeofencingLocationManagerCoreDataDelegate : NSObject, CLLocationManagerDelegate {
    weak var loiteringQueue: LoiterOperationQueue!
    weak var repository: GeofencingCoreDataRepository!
    
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        guard let region = region as? CLCircularRegion else {
            return
        }
        
        GeofencingStack.shared.performUpdate {[unowned self] (context) in
            guard let geofence = self.repository.geofence(with: region.identifier, context: context) else {
                return
            }
            
            if let loiterEvent = self.repository.loitering(for: region, using: context) {
                let now = Date()
                let timeSinceLoiter = now.timeIntervalSince(loiterEvent.start!)
                
                let timeDifference = timeSinceLoiter - loiterEvent.delay
                
                switch state {
                case .inside:
                    if timeSinceLoiter > 2 * geofence.loiter {
                        let event = NSEntityDescription.insertNewObject(forEntityName: String(describing: CDGeofenceEvent.self), into: context) as! CDGeofenceEvent
                        event.eventId = UUID().uuidString
                        event.type = GeofenceEventType.dwell.rawValue
                        context.delete(loiterEvent)
                        
                        self.loiteringQueue.addOperation(for: region, with: UInt32(Constants.loiter))
                        
                        let newLoiter = NSEntityDescription.insertNewObject(forEntityName: String(describing: CDLoiterEvent.self), into: context) as! CDLoiterEvent
                        
                        newLoiter.delay = Double(Constants.loiter)
                        newLoiter.start = Date()
                        geofence.addToEvents(event)
                        geofence.loiterEvent = newLoiter
                        return
                    }
                    
                    if timeDifference < 0 { // we still need to loiter for the remaining time
                        let remainingTime = abs(timeDifference)
                        self.loiteringQueue.addOperation(for: region, with: UInt32(remainingTime))
                        context.delete(loiterEvent)
                        
                        let newLoiter = NSEntityDescription.insertNewObject(forEntityName: String(describing: CDLoiterEvent.self), into: context) as! CDLoiterEvent
                        
                        newLoiter.delay = remainingTime
                        newLoiter.geofence = geofence
                        newLoiter.start = Date()
                        geofence.loiterEvent = newLoiter
                        
                    } else {
                        // Add entry
                        let event = NSEntityDescription.insertNewObject(forEntityName: String(describing: CDGeofenceEvent.self), into: context) as! CDGeofenceEvent
                        event.eventId = UUID().uuidString
                        event.type = GeofenceEventType.entry.rawValue
                        
                        // Remove loiter
                        context.delete(loiterEvent)
                        
                        geofence.addToEvents(event)
                    }
                case .outside:
                    let event = NSEntityDescription.insertNewObject(forEntityName: String(describing: CDGeofenceEvent.self), into: context) as! CDGeofenceEvent
                    event.eventId = UUID().uuidString
                    event.type = GeofenceEventType.exit.rawValue
                    context.delete(loiterEvent)
                    geofence.addToEvents(event)
                    
                default:
                    break
                }
            } else {
                switch state {
                case .inside:
                    if let event = self.repository.lastEvent(for: region, using: context), event.type == "enter" {
                        return
                    }
                    
                    let event = NSEntityDescription.insertNewObject(forEntityName: String(describing: CDGeofenceEvent.self), into: context) as! CDGeofenceEvent
                    event.eventId = UUID().uuidString
                    event.type = GeofenceEventType.dwell.rawValue
                    
                    self.loiteringQueue?.addOperation(for: region, with: UInt32(Constants.loiter))
                    
                    let newLoiter = NSEntityDescription.insertNewObject(forEntityName: String(describing: CDLoiterEvent.self), into: context) as! CDLoiterEvent
                    
                    newLoiter.delay = Double(Constants.loiter)
                    newLoiter.start = Date()
                    geofence.addToEvents(event)
                    geofence.loiterEvent = newLoiter
                    
                case .outside:
                    if let event = self.repository.lastEvent(for: region, using: context), [GeofenceEventType.exit, GeofenceEventType.start, GeofenceEventType.fail].map({$0.rawValue}).contains(event.type)  {
                        return
                    }
                    
                    let event = NSEntityDescription.insertNewObject(forEntityName: String(describing: CDGeofenceEvent.self), into: context) as! CDGeofenceEvent
                    event.eventId = UUID().uuidString
                    event.type = GeofenceEventType.exit.rawValue
                    geofence.addToEvents(event)
                default:
                    break
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        GeofencingStack.shared.performUpdate {[unowned self] (context) in
            guard let geofence = self.repository.geofence(with: region.identifier, context: context) else {
                return
            }
            
            let event = NSEntityDescription.insertNewObject(forEntityName: String(describing: CDGeofenceEvent.self), into: context) as! CDGeofenceEvent
            event.eventId = UUID().uuidString
            event.type = GeofenceEventType.start.rawValue
            
            geofence.addToEvents(event)
        }
        
        manager.requestState(for: region)
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        if let region = region {
            GeofencingStack.shared.performUpdate {[unowned self] (context) in
                guard let geofence = self.repository.geofence(with: region.identifier, context: context) else {
                    return
                }
                
                let event = NSEntityDescription.insertNewObject(forEntityName: String(describing: CDGeofenceEvent.self), into: context) as! CDGeofenceEvent
                event.eventId = UUID().uuidString
                event.type = GeofenceEventType.fail.rawValue
                
                geofence.addToEvents(event)
            }
        }
    }

}
