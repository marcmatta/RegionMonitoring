//
//  Stack.swift
//  RegionMonitoring
//
//  Created by Mymac on 11/1/18.
//  Copyright © 2018 marxmatta. All rights reserved.
//

import UIKit
import CoreData

class GeofencingStack: NSObject {
    private let persistentContainer = NSPersistentContainer(name: "RegionMonitoring")
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    static let shared = GeofencingStack()
    
    func load(completion: @escaping ()->Void)  {
        self.persistentContainer.loadPersistentStores() {[weak self] (description, error) in
            self?.persistentContainer.viewContext.automaticallyMergesChangesFromParent = true

            completion()
        }
    }
    
    func destroy() {
        guard let storeURL = persistentContainer.persistentStoreCoordinator.persistentStores.first?.url else {
            return
        }
        do {
            try self.persistentContainer.persistentStoreCoordinator.destroyPersistentStore(at: storeURL, ofType: NSSQLiteStoreType, options: nil)
        } catch {
            print(error)
        }
    }
    
    func saveContext () -> Bool {
        return persistentContainer.viewContext.saveIfHasChanges()
        
    }
    
    func performTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        persistentContainer.performBackgroundTask(block)
    }
    
    func performUpdate(_ block: @escaping (NSManagedObjectContext) -> Void) {
        performTask({ ctx in
            block(ctx)
            ctx.saveIfHasChanges()
        })
    }
}

extension NSManagedObjectContext {
    @discardableResult
    func saveIfHasChanges() -> Bool {
        guard self.hasChanges else { return true }
        do {
            try save()
            return true
        } catch {
            return false
        }
    }
}


