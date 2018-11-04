//
//  GeofencingRepository.swift
//  RegionMonitoring
//
//  Created by Mymac on 11/2/18.
//  Copyright © 2018 marxmatta. All rights reserved.
//

import Foundation
import CoreLocation
import CoreData

class GeofencingCoreDataRepository {
    func removeGeofence(for region: CLRegion) {
        GeofencingStack.shared.performUpdate {[unowned self] (context) in
            if let geofence = self.geofence(with: region.identifier, context: context) {
                context.delete(geofence)
            }
        }
    }
    
    func geofence(with identifier: String, context: NSManagedObjectContext) -> CDGeofence? {
        let fetchRequest : NSFetchRequest<CDGeofence> = CDGeofence.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "identifier = %@", identifier)
        fetchRequest.fetchLimit = 1
        
        return (try? context.fetch(fetchRequest))?.first
    }
    
    func lastEvent(for region: CLRegion, using context: NSManagedObjectContext) -> CDGeofenceEvent? {
        let fetchRequest: NSFetchRequest<CDGeofenceEvent> = CDGeofenceEvent.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "geofence.identifier = %@", region.identifier)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        fetchRequest.fetchLimit = 1
        
        return (try? context.fetch(fetchRequest))?.first
    }
    
    func loitering(for region: CLCircularRegion, using context: NSManagedObjectContext) -> CDLoiterEvent? {
        let fetchRequest: NSFetchRequest<CDLoiterEvent> = CDLoiterEvent.fetchRequest()
        //        let epsilon = 0.000001
        //        fetchRequest.predicate = NSPredicate(format:"geofence.latitude > %lf AND geofence.latitude < %lf AND geofence.longitude > %lf AND geofence.longitude < %lf", region.center.latitude - epsilon,  region.center.latitude + epsilon, region.center.longitude - epsilon, region.center.longitude + epsilon)
        fetchRequest.predicate = NSPredicate(format: "geofence.identifier = %@", region.identifier)
        fetchRequest.fetchLimit = 1
        return (try? context.fetch(fetchRequest))?.first
    }
}
