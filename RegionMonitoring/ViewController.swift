//
//  ViewController.swift
//  RegionMonitoring
//
//  Created by Mymac on 11/1/18.
//  Copyright © 2018 marxmatta. All rights reserved.
//

import UIKit
import MapKit
import CoreData
import CoreLocation

struct Constants {
    static let radius: CLLocationDistance = 50
    static let loiter: UInt32 = 15
    static let expectedCheckout: Double = 60
    static let maxCheckout: Double = 120
}

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

class ViewController: UIViewController {
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var tableView: UITableView!
    
    let locationManager = CLLocationManager()
    lazy var loiteringQueue : LoiterOperationQueue = {
        return LoiterOperationQueue(manager: locationManager)
    }()
    
    var annotations : [RegionAnnotation: MKOverlay] = [:]
    
    lazy var fetchedResultsController : NSFetchedResultsController<GeofenceEvent> = {
        let request : NSFetchRequest<GeofenceEvent> = GeofenceEvent.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        let controller = NSFetchedResultsController(fetchRequest: request, managedObjectContext: CoreDataStack.shared.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        controller.delegate = self
        
        return controller
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.locationManager.delegate = self
        if CLLocationManager.authorizationStatus() == .notDetermined {
            self.locationManager.requestAlwaysAuthorization()
        }
        
        self.mapView.delegate = self
        self.mapView.showsUserLocation = true
        self.mapView.userTrackingMode = .follow
        self.mapView.register(MKPinAnnotationView.self, forAnnotationViewWithReuseIdentifier: "region")
        
        
        let regions = locationManager.monitoredRegions.map{$0 as! CLCircularRegion}
        regions.forEach {[weak self] (region) in
            if let self = self {
                let annotation = RegionAnnotation(region: region)
                let overlay = annotation.overlay()
                
                self.mapView.addAnnotation(annotation)
                self.mapView.addOverlay(overlay)
                
                self.annotations[annotation] = overlay
            }
        }
        
        self.tableView.dataSource = self
        do {
            try self.fetchedResultsController.performFetch()
            self.tableView.reloadData()
        }
        catch {
            print("error fetching updates")
        }
    }
    
    @IBAction func addRegion(_ sender: Any) {
        CoreDataStack.shared.performUpdate {[unowned self] (context) in
            let center = self.mapView.centerCoordinate
            
            let geofence = NSEntityDescription.insertNewObject(forEntityName: "\(Geofence.self)", into: context) as! Geofence
            
            geofence.identifier = UUID().uuidString
            geofence.expectedCheckout = Constants.expectedCheckout
            geofence.maxCheckout = Constants.maxCheckout
            geofence.name = "region \(center)"
            geofence.details = "radius \(Constants.radius)"
            geofence.latitude = center.latitude
            geofence.longitude = center.longitude
            geofence.loiter = Double(Constants.loiter)
            geofence.locationRequired = true
            
            self.addRegion(from: geofence)
            self.startMonitoring(for: geofence.region)
        }
    }
    
    func addRegion(from geofence: Geofence) {
        DispatchQueue.main.async {
            let region = geofence.region
            
            let annotation = RegionAnnotation(region: region)
            self.mapView.addAnnotation(annotation)
            self.mapView.addOverlay(annotation.overlay())
        }
    }
    
    func startMonitoring(for region: CLRegion) {
        DispatchQueue.main.async { [weak self] in
            self?.locationManager.startMonitoring(for: region)
        }
    }
    
    func stopMonitoring(for region: CLRegion) {
        DispatchQueue.main.async { [weak self] in
            self?.locationManager.stopMonitoring(for: region)
            self?.removeGeofence(for: region)
        }
    }
    
    @IBAction func switchView(_ sender: Any) {
        self.mapView.isHidden = !self.mapView.isHidden
        self.tableView.isHidden = !self.tableView.isHidden
    }
    
}

extension RegionAnnotation {
    func overlay() -> MKCircle {
        return MKCircle(center: region.center, radius: region.radius)
    }
}

extension ViewController: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            tableView.insertRows(at: [newIndexPath!], with: .fade)
        case .delete:
            tableView.deleteRows(at: [indexPath!], with: .fade)
        case .update:
            tableView.reloadRows(at: [indexPath!], with: .fade)
        case .move:
            tableView.moveRow(at: indexPath!, to: newIndexPath!)
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
}

extension ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fetchedResultsController.fetchedObjects?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let event = fetchedResultsController.object(at: indexPath)
        cell.textLabel?.text = event.geofence?.name ?? ""
        cell.detailTextLabel?.text = "\(event.type!) at \(event.date!)"
        return cell
    }
}

extension ViewController {
    func removeGeofence(for region: CLRegion) {
        CoreDataStack.shared.performUpdate {[unowned self] (context) in
            if let geofence = self.geofence(with: region.identifier, context: context) {
                context.delete(geofence)
            }
        }
    }
    
    func geofence(with identifier: String, context: NSManagedObjectContext) -> Geofence? {
        let fetchRequest : NSFetchRequest<Geofence> = Geofence.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "identifier = %@", identifier)
        fetchRequest.fetchLimit = 1
        
        return (try? context.fetch(fetchRequest))?.first
    }
    
    func lastEvent(for region: CLRegion, using context: NSManagedObjectContext) -> GeofenceEvent? {
        let fetchRequest: NSFetchRequest<GeofenceEvent> = GeofenceEvent.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "geofence.identifier = %@", region.identifier)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        fetchRequest.fetchLimit = 1
        
        return (try? context.fetch(fetchRequest))?.first
    }
    
    func loitering(for region: CLCircularRegion, using context: NSManagedObjectContext) -> LoiterEvents? {
        let fetchRequest: NSFetchRequest<LoiterEvents> = LoiterEvents.fetchRequest()
//        let epsilon = 0.000001
//        fetchRequest.predicate = NSPredicate(format:"geofence.latitude > %lf AND geofence.latitude < %lf AND geofence.longitude > %lf AND geofence.longitude < %lf", region.center.latitude - epsilon,  region.center.latitude + epsilon, region.center.longitude - epsilon, region.center.longitude + epsilon)
        fetchRequest.predicate = NSPredicate(format: "geofence.identifier = %@", region.identifier)
        fetchRequest.fetchLimit = 1
        return (try? context.fetch(fetchRequest))?.first
    }
}

extension ViewController: MKMapViewDelegate {
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
            if let overlay = self.annotations[annotation] {
                self.mapView.removeOverlay(overlay)
                self.annotations.removeValue(forKey: annotation)
            }
            
            self.mapView.removeAnnotation(annotation)
            stopMonitoring(for: annotation.region)
        }
    }
    
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        let userLocation = MKCoordinateRegion(center: userLocation.coordinate, latitudinalMeters: 1500, longitudinalMeters: 1500)
        self.mapView.setRegion(userLocation, animated: true)
    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, didChange newState: MKAnnotationView.DragState, fromOldState oldState: MKAnnotationView.DragState) {
        guard let annotation = view.annotation as? RegionAnnotation else{
            return
        }
        
        if newState == .starting {
            if let overlay = self.annotations[annotation] {
                mapView.removeOverlay(overlay)
                
                stopMonitoring(for: annotation.region)
            }
        }
        
        if oldState == .dragging && newState == .ending {
            let newCenter = annotation.coordinate
            let region = annotation.region
            self.removeGeofence(for: region)
            
            if let overlay = self.annotations[annotation]{
                self.mapView.removeOverlay(overlay)
            }
            self.annotations.removeValue(forKey: annotation)
            self.mapView.removeAnnotation(annotation)
            
            self.mapView.centerCoordinate = newCenter
            
            self.addRegion(mapView)
        }
    }
}

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

extension ViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        guard let region = region as? CLCircularRegion else {
            return
        }
            
        CoreDataStack.shared.performUpdate {[unowned self] (context) in
            guard let geofence = self.geofence(with: region.identifier, context: context) else {
                return
            }
            
            if let loiterEvent = self.loitering(for: region, using: context) {
                let now = Date()
                let timeSinceLoiter = now.timeIntervalSince(loiterEvent.start!)
                
                let timeDifference = timeSinceLoiter - loiterEvent.delay
                
                switch state {
                case .inside:
                    if timeSinceLoiter > 2 * geofence.loiter {
                        let event = NSEntityDescription.insertNewObject(forEntityName: String(describing: GeofenceEvent.self), into: context) as! GeofenceEvent
                        event.eventId = UUID().uuidString
                        event.type = "dwell"
                        context.delete(loiterEvent)
                        
                        self.loiteringQueue.addOperation(for: region, with: UInt32(Constants.loiter))
                        
                        let newLoiter = NSEntityDescription.insertNewObject(forEntityName: String(describing: LoiterEvents.self), into: context) as! LoiterEvents
                        
                        newLoiter.delay = Double(Constants.loiter)
                        newLoiter.start = Date()
                        geofence.addToEvents(event)
                        geofence.loiterEvent = newLoiter
                        return
                    }
                    
                    if timeDifference < 0 { // we still need to loiter for the remaining time
                        let remainingTime = abs(timeDifference)
                        self.loiteringQueue.addOperation(for: region, with: UInt32(remainingTime))
                        context.delete(loiterEvent)
                        
                        let newLoiter = NSEntityDescription.insertNewObject(forEntityName: String(describing: LoiterEvents.self), into: context) as! LoiterEvents
                            
                        newLoiter.delay = remainingTime
                        newLoiter.geofence = geofence
                        newLoiter.start = Date()
                        geofence.loiterEvent = newLoiter
                        
                    } else {
                        // Add entry
                        let event = NSEntityDescription.insertNewObject(forEntityName: String(describing: GeofenceEvent.self), into: context) as! GeofenceEvent
                        event.eventId = UUID().uuidString
                        event.type = "enter"
                        
                        // Remove loiter
                        context.delete(loiterEvent)
                        
                        geofence.addToEvents(event)
                    }
                case .outside:
                    let event = NSEntityDescription.insertNewObject(forEntityName: String(describing: GeofenceEvent.self), into: context) as! GeofenceEvent
                    event.eventId = UUID().uuidString
                    event.type = "exit"
                    context.delete(loiterEvent)
                    geofence.addToEvents(event)

                default:
                    break
                }
            } else {
                switch state {
                case .inside:
                    if let event = self.lastEvent(for: region, using: context), event.type == "enter" {
                        return
                    }
                    
                    let event = NSEntityDescription.insertNewObject(forEntityName: String(describing: GeofenceEvent.self), into: context) as! GeofenceEvent
                    event.eventId = UUID().uuidString
                    event.type = "dwell"
                    
                    self.loiteringQueue.addOperation(for: region, with: UInt32(Constants.loiter))
                    
                    let newLoiter = NSEntityDescription.insertNewObject(forEntityName: String(describing: LoiterEvents.self), into: context) as! LoiterEvents
                    
                    newLoiter.delay = Double(Constants.loiter)
                    newLoiter.start = Date()
                    geofence.addToEvents(event)
                    geofence.loiterEvent = newLoiter

                case .outside:
                    if let event = self.lastEvent(for: region, using: context), ["exit", "start", "fail"].contains(event.type)  {
                        return
                    }
                    
                    let event = NSEntityDescription.insertNewObject(forEntityName: String(describing: GeofenceEvent.self), into: context) as! GeofenceEvent
                    event.eventId = UUID().uuidString
                    event.type = "exit"
                    geofence.addToEvents(event)
                default:
                    break
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        CoreDataStack.shared.performUpdate { (context) in
            guard let geofence = self.geofence(with: region.identifier, context: context) else {
                return
            }
            
            let event = NSEntityDescription.insertNewObject(forEntityName: String(describing: GeofenceEvent.self), into: context) as! GeofenceEvent
            event.eventId = UUID().uuidString
            event.type = "start"
            
            geofence.addToEvents(event)
        }
        
        manager.requestState(for: region)
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        if let region = region {
            CoreDataStack.shared.performUpdate { (context) in
                guard let geofence = self.geofence(with: region.identifier, context: context) else {
                    return
                }

                let event = NSEntityDescription.insertNewObject(forEntityName: String(describing: GeofenceEvent.self), into: context) as! GeofenceEvent
                event.eventId = UUID().uuidString
                event.type = "fail"
                
                geofence.addToEvents(event)
            }
        }
    }
}

extension GeofenceEvent {
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        date = Date()
    }
}

extension Geofence {
    var region: CLCircularRegion {
        let region = CLCircularRegion(center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), radius: radius, identifier: identifier!)
        region.notifyOnEntry = true
        region.notifyOnExit = true
        return region
    }
}
