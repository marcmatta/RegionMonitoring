//
//  GeofencingLocationManager.swift
//  RegionMonitoring
//
//  Created by Mymac on 11/2/18.
//  Copyright © 2018 marxmatta. All rights reserved.
//

import Foundation
import CoreLocation

class GeofencingLocationManager {
    var locationManager = CLLocationManager()
    
    lazy var loiteringQueue : LoiterOperationQueue = {
        return LoiterOperationQueue(manager: locationManager)
    }()
    
    var geofencingDelegate = GeofencingLocationManagerCoreDataDelegate()
    var repository = GeofencingCoreDataRepository()
    
    init() {
        geofencingDelegate.repository = repository
        geofencingDelegate.loiteringQueue = loiteringQueue
        locationManager.delegate = geofencingDelegate
    }
    
    func startMonitoring(for region: CLRegion) {
        DispatchQueue.main.async { [weak manager=locationManager] in
            manager?.startMonitoring(for: region)
        }
    }
    
    func stopMonitoring(for region: CLRegion) {
        DispatchQueue.main.async { [weak self] in
            self?.locationManager.stopMonitoring(for: region)
            self?.repository.removeGeofence(for: region)
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
}
