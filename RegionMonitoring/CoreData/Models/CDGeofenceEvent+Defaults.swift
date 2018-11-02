//
//  GeofenceEvent+Defaults.swift
//  RegionMonitoring
//
//  Created by Mymac on 11/2/18.
//  Copyright © 2018 marxmatta. All rights reserved.
//

import Foundation

extension CDGeofenceEvent {
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        date = Date()
    }
}
