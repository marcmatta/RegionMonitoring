//
//  Geofence+Defaults.swift
//  RegionMonitoring
//
//  Created by Mymac on 11/2/18.
//  Copyright © 2018 marxmatta. All rights reserved.
//

import CoreLocation
extension CDGeofence {
    var region: CLCircularRegion {
        let region = CLCircularRegion(center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), radius: radius, identifier: identifier!)
        region.notifyOnEntry = true
        region.notifyOnExit = true
        return region
    }
}
