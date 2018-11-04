//
//  RegionAnnotation.swift
//  RegionMonitoring
//
//  Created by Mymac on 11/2/18.
//  Copyright © 2018 marxmatta. All rights reserved.
//

import Foundation
import MapKit

class RegionAnnotation : NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    
    var region: CLCircularRegion
    
    init(region: CLCircularRegion) {
        self.region = region
        self.coordinate = region.center
    }
    
    var title: String? {
        return "\(coordinate.latitude), \(coordinate.longitude)"
    }
    
    var subtitle: String? {
        return "\(region.identifier)"
    }
}

extension RegionAnnotation {
    func overlay() -> MKCircle {
        return MKCircle(center: region.center, radius: region.radius)
    }
}
