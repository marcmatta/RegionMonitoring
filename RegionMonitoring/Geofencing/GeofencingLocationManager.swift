//
//  GeofencingLocationManager.swift
//  RegionMonitoring
//
//  Created by Mymac on 11/2/18.
//  Copyright © 2018 marxmatta. All rights reserved.
//

import Foundation
import CoreLocation
import CoreData

class GeofencingLocationManager {
    var locationManager = CLLocationManager()
    
    lazy var loiteringQueue : LoiterOperationQueue = {
        return LoiterOperationQueue(manager: locationManager)
    }()
    
    var geofencingDelegate = GeofencingLocationManagerCoreDataDelegate()
    var syncManager = GeofenceEventSyncManager()
    
    init() {
        geofencingDelegate.loiteringQueue = loiteringQueue
        locationManager.delegate = geofencingDelegate
        
        syncManager.load()
    }
    
    func startMonitoring(for region: CLRegion) {
        DispatchQueue.main.async { [weak manager=locationManager] in
            manager?.startMonitoring(for: region)
        }
    }
    
    func stopMonitoring(for region: CLRegion) {
        DispatchQueue.main.async { [weak self] in
            self?.locationManager.stopMonitoring(for: region)
            GeofencingCoreDataRepository.removeGeofence(for: region)
        }
    }
    
    var monitoredRegions: [CLCircularRegion] {
        return locationManager.monitoredRegions.map{$0 as! CLCircularRegion}
    }
    
    func start() {
        if CLLocationManager.authorizationStatus() == .notDetermined {
            DispatchQueue.main.async { [unowned self] in
                self.locationManager.requestAlwaysAuthorization()
            }
        }
    }
    
    func stop() {
        self.locationManager.monitoredRegions.forEach {[unowned self] (region) in
            self.locationManager.stopMonitoring(for: region)
        }
        
        GeofencingCoreDataRepository.removeAllGeofences()
    }
}
