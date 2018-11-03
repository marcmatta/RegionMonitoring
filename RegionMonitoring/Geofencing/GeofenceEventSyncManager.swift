//
//  File.swift
//  RegionMonitoring
//
//  Created by Mymac on 11/2/18.
//  Copyright © 2018 marxmatta. All rights reserved.
//

import Foundation
import CoreData

class GeofenceEventSyncManager: NSObject {
    var operationQueue = OperationQueue()
    
    lazy var unsynced : NSFetchedResultsController<CDGeofenceEvent> = {
        let fetchRequest: NSFetchRequest<CDGeofenceEvent> = CDGeofenceEvent.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "synced = false")
        fetchRequest.propertiesToFetch = ["eventId"]
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        let controller = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: GeofencingStack.shared.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        controller.delegate = self
        return controller
    }()
    
    func load() {
        try? unsynced.performFetch()
        
        unsynced.fetchedObjects?.forEach({[weak self] in
            self?.operationQueue.addOperation(SyncGeofenceEventOperation(eventId: $0.eventId!))
        })
    }
}

class SyncGeofenceEventOperation: Operation {
    let eventId: String
    
    init(eventId: String) {
        self.eventId = eventId
    }
    
    override func main() {
        if isCancelled {
            return
        }
        
        let context = GeofencingStack.shared.newBackgroundContext()
        let fetchRequest : NSFetchRequest<CDGeofenceEvent> = CDGeofenceEvent.fetchRequest()
        fetchRequest.predicate =  NSPredicate(format: "eventId = %@", eventId)
        fetchRequest.fetchLimit = 1
        
        if let event = ((try? context.fetch(fetchRequest))?.first) {
            // Upload event synchronously
            let semaphore = DispatchSemaphore(value: 0)
            
            DispatchQueue.global(qos: .background).async { [weak self] in
                self?.perform(semaphore: semaphore)
                guard let self = self, !self.isCancelled else {
                    return
                }
                
                event.synced = true
            }
            
            _ = semaphore.wait(timeout: DispatchTime.distantFuture)
            context.saveIfHasChanges()
        }
        
        if isCancelled {
            return
        }
    }
    
    private func perform(semaphore: DispatchSemaphore) {
        semaphore.signal()
    }
}

extension GeofenceEventSyncManager: NSFetchedResultsControllerDelegate {
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        if let indexPath = indexPath {
            let object = controller.object(at: indexPath) as! CDGeofenceEvent
            switch type {
            case .insert:
                operationQueue.addOperation(SyncGeofenceEventOperation(eventId: object.eventId!))
            case .delete:
                operationQueue.operations.map { $0 as! SyncGeofenceEventOperation }.first { (operation) -> Bool in
                    return operation.eventId == object.eventId
                }?.cancel()
            default:
                break
            }
        }
    }
}
