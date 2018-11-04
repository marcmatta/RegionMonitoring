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

class GeofencingViewController: UIViewController {
    @IBOutlet weak var mapView: GeofencingMapView!
    @IBOutlet weak var tableView: UITableView!
    
    let geofencingManager = GeofencingLocationManager()
    
    lazy var fetchedResultsController : NSFetchedResultsController<CDGeofenceEvent> = {
        let request : NSFetchRequest<CDGeofenceEvent> = CDGeofenceEvent.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        let controller = NSFetchedResultsController(fetchRequest: request, managedObjectContext: GeofencingStack.shared.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        controller.delegate = self
        
        return controller
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        geofencingManager.start()
        mapView.geofencingManager = geofencingManager
                
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
        self.mapView.addRegion()
    }
    
    @IBAction func switchView(_ sender: Any) {
        self.mapView.isHidden = !self.mapView.isHidden
        self.tableView.isHidden = !self.tableView.isHidden
    }
}

extension GeofencingViewController: NSFetchedResultsControllerDelegate {
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

extension GeofencingViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fetchedResultsController.fetchedObjects?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let event = fetchedResultsController.object(at: indexPath)
        cell.textLabel?.text = event.geofence?.name ?? ""
        cell.detailTextLabel?.text = "\(event.type!) at \(event.date!)"
        cell.contentView.backgroundColor = event.synced ? UIColor.green.withAlphaComponent(0.2) : UIColor.yellow.withAlphaComponent(0.2)
        return cell
    }
}
