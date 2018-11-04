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
    var syncAction : SyncGeofenceEventOperation.SyncGeofenceEventAction
    
    lazy var unsynced : NSFetchedResultsController<CDGeofenceEvent> = {
        let fetchRequest: NSFetchRequest<CDGeofenceEvent> = CDGeofenceEvent.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "synced = false")
        fetchRequest.propertiesToFetch = ["eventId"]
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        let controller = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: GeofencingStack.shared.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        controller.delegate = self
        return controller
    }()
    
    init(syncAction: @escaping SyncGeofenceEventOperation.SyncGeofenceEventAction) {
        self.syncAction = syncAction
        super.init()
        
        try? unsynced.performFetch()
        
        unsynced.fetchedObjects?.forEach({[weak self] in
            let operation = SyncGeofenceEventOperation(eventId: $0.eventId!)
            operation.action = syncAction
            self?.operationQueue.addOperation(operation)
        })
    }
}

enum SyncGeofenceEventResult {
    case failed
    case synced
}

class SyncGeofenceEventOperation: Operation {
    typealias SyncGeofenceEventAction = (_ completion: (SyncGeofenceEventResult) -> Void)->Void
    fileprivate var action: SyncGeofenceEventAction?
    let semaphore = DispatchSemaphore(value: 0)
    private lazy var completion: (SyncGeofenceEventResult) -> Void = {
        return {[weak self] result in
            if let self = self {
                switch result {
                case .failed:
                    self.perform()
                case .synced:
                    GeofencingCoreDataRepository.didSyncGeofenceEvent(with: self.eventId)
                    self.semaphore.signal()
                }
            }
        }
    }()
    
    let eventId: String
    init(eventId: String) {
        self.eventId = eventId
        super.init()
    }
    
    override func main() {
        if isCancelled {
            return
        }
        
        let context = GeofencingStack.shared.newBackgroundContext()
        if let _ = GeofencingCoreDataRepository.geofenceEvent(with: eventId, context: context) {
            // Upload event synchronously
            
            DispatchQueue.global(qos: .background).asyncAfter(deadline: DispatchTime.now() + 2) { [weak self] in
                self?.perform()
            }
            
            _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        }
    }
    
    private func perform() {
        action?(completion)
    }
}

extension GeofenceEventSyncManager: NSFetchedResultsControllerDelegate {
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        if let object = anObject as? CDGeofenceEvent {
            switch type {
            case .insert:
                let operation = SyncGeofenceEventOperation(eventId: object.eventId!)
                operation.action = syncAction
                operationQueue.addOperation(operation)
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
