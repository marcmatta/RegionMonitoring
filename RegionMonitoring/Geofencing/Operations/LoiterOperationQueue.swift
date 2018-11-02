//
//  LoiterOperationQueue.swift
//  RegionMonitoring
//
//  Created by Mymac on 11/2/18.
//  Copyright © 2018 marxmatta. All rights reserved.
//

import Foundation
import CoreLocation

class LoiterOperationQueue : OperationQueue {
    let manager : CLLocationManager
    init(manager : CLLocationManager) {
        self.manager = manager
        super.init()
        self.name = "Geofencing loitering queue"
        self.maxConcurrentOperationCount = OperationQueue.defaultMaxConcurrentOperationCount
    }
    
    func addOperation(for region: CLCircularRegion, with delay: UInt32) {
        let operation = LoiterOperation(region: region, delay: delay, manager: manager)
        self.addOperation(operation)
    }
}
