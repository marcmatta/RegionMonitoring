//
//  Geofencing+Enumeration.swift
//  RegionMonitoring
//
//  Created by Mymac on 11/2/18.
//  Copyright © 2018 marxmatta. All rights reserved.
//

import Foundation
enum GeofenceEventType : String, CustomStringConvertible {
    var description: String {
        return self.rawValue
    }
    
    case dwell = "dwell"
    case entry = "entry"
    case exit  = "exit"
    case start = "start"
    case fail = "fail"
}
