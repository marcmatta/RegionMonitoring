//
//  LoiterOperation.swift
//  RegionMonitoring
//
//  Created by Mymac on 11/2/18.
//  Copyright © 2018 marxmatta. All rights reserved.
//

import Foundation
import CoreLocation

class LoiterOperation: Operation {
    let region : CLCircularRegion
    let delay: UInt32
    unowned var locationManager: CLLocationManager
    
    init(region : CLCircularRegion, delay: UInt32, manager: CLLocationManager) {
        self.region = region
        self.delay = delay
        self.locationManager = manager
        super.init()
    }
    
    override func main() {
        if isCancelled {
            return
        }
        
        sleep(delay)
        
        if isCancelled {
            return
        }
        
        OperationQueue.main.addOperation {
            self.locationManager.requestState(for: self.region)
        }
    }
}
