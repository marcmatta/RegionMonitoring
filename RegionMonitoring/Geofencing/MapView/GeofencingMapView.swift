//
//  GeofencingMapView.swift
//  RegionMonitoring
//
//  Created by Mymac on 11/2/18.
//  Copyright © 2018 marxmatta. All rights reserved.
//

import MapKit
import CoreData

class GeofencingMapView: MKMapView {
    weak var geofencingManager: GeofencingLocationManager? {
        didSet {
            guard let geofencingManager = geofencingManager else {
                return
            }
            
            let regions = geofencingManager.monitoredRegions
            
            regions.forEach {[weak self] (region) in
                if let self = self {
                    let annotation = RegionAnnotation(region: region)
                    let overlay = annotation.overlay()
                    
                    self.addAnnotation(annotation)
                    self.addOverlay(overlay)
                    
                    self.annotationOverlays[region.identifier] = overlay
                }
            }
        }
    }
    
    var annotationOverlays : [String: MKOverlay] = [:]

    override func willMove(toSuperview newSuperview: UIView?) {
        self.delegate = self
        self.showsUserLocation = true
        self.userTrackingMode = .follow
        self.register(MKPinAnnotationView.self, forAnnotationViewWithReuseIdentifier: "region")
    }
    
    func addRegion() {
        let center = self.centerCoordinate
        GeofencingStack.shared.performUpdate {[unowned self] (context) in
            
            let geofence = NSEntityDescription.insertNewObject(forEntityName: String(describing: CDGeofence.self), into: context) as! CDGeofence
            
            geofence.identifier = UUID().uuidString
            geofence.expectedCheckout = Constants.expectedCheckout
            geofence.maxCheckout = Constants.maxCheckout
            geofence.name = "region \(center)"
            geofence.details = "radius \(Constants.radius)"
            geofence.latitude = center.latitude
            geofence.longitude = center.longitude
            geofence.loiter = Double(Constants.loiter)
            geofence.locationRequired = true
            
            self.addRegion(from: geofence.region)
            self.geofencingManager?.startMonitoring(for: geofence.region)
        }
    }
    
    func addRegion(from region: CLCircularRegion) {
        DispatchQueue.main.async {
            let annotation = RegionAnnotation(region: region)
            self.addAnnotation(annotation)
            let overlay = annotation.overlay()
            self.addOverlay(overlay)
            self.annotationOverlays[region.identifier] = overlay
        }
    }
}

extension GeofencingMapView: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKCircleRenderer(circle: overlay as! MKCircle)
        renderer.fillColor = UIColor.purple.withAlphaComponent(0.4)
        renderer.strokeColor = UIColor.purple
        return renderer
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let annotation = annotation as? RegionAnnotation else {
            return nil
        }
        
        let view = mapView.dequeueReusableAnnotationView(withIdentifier: "region", for: annotation) as! MKPinAnnotationView
        
        view.annotation = annotation
        view.canShowCallout = true
        view.isMultipleTouchEnabled = false
        view.isDraggable = true
        view.animatesDrop = true
        view.pinTintColor = .purple
        
        let removeButton = UIButton(type: .custom)
        let image = UIImage(named: "RemoveRegion")
        removeButton.setImage(image, for: .normal)
        removeButton.sizeToFit()
        view.leftCalloutAccessoryView = removeButton
        return view
    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        if let annotation = view.annotation as? RegionAnnotation {
            if let overlay = self.annotationOverlays[annotation.region.identifier] {
                self.removeOverlay(overlay)
                self.annotationOverlays.removeValue(forKey: annotation.region.identifier)
            }
            
            self.removeAnnotation(annotation)
            self.geofencingManager?.stopMonitoring(for: annotation.region)
        }
    }
    
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        let userLocation = MKCoordinateRegion(center: userLocation.coordinate, latitudinalMeters: 1500, longitudinalMeters: 1500)
        self.setRegion(userLocation, animated: true)
    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, didChange newState: MKAnnotationView.DragState, fromOldState oldState: MKAnnotationView.DragState) {
        guard let annotation = view.annotation as? RegionAnnotation else{
            return
        }
        
        if newState == .starting {
            if let overlay = self.annotationOverlays[annotation.region.identifier] {
                mapView.removeOverlay(overlay)
                
                self.geofencingManager?.stopMonitoring(for: annotation.region)
            }
        }
        
        if oldState == .dragging && newState == .ending {
            let newCenter = annotation.coordinate
            let region = annotation.region
            
            if let overlay = self.annotationOverlays[region.identifier]{
                self.removeOverlay(overlay)
                self.annotationOverlays.removeValue(forKey: region.identifier)
            }
            
            self.removeAnnotation(annotation)
            self.centerCoordinate = newCenter
            
            self.geofencingManager?.repository.removeGeofence(for: region)

            self.addRegion()
        }
    }
}
