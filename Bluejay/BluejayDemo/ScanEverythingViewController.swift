//
//  PeripheralsViewController.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-02-27.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import UIKit
import Bluejay

class ScanEverythingViewController: UITableViewController {
    
    private let bluejay = Bluejay()
    
    private var peripherals = [ScanDiscovery]() {
        didSet {
            peripherals.sort { (a, b) -> Bool in
                return a.rssi < b.rssi
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        debugPrint("Bluejay started: \(bluejay.hasStarted)")
        
        bluejay.start()
                
        debugPrint("Bluejay started: \(bluejay.hasStarted)")
        
        startScanning()
    }
    
    private func startScanning() {
        bluejay.scan(
            duration: 5,
            allowDuplicates: true,
            serviceIdentifiers: nil,
            discovery: { [weak self] (discovery, discoveries) -> ScanAction in
                guard let weakSelf = self else {
                    return .stop
                }
                
                weakSelf.peripherals = discoveries
                weakSelf.tableView.reloadData()
                
                return .continue
            },
            expired: { [weak self] (lostDiscovery, discoveries) -> ScanAction in
                guard let weakSelf = self else {
                    return .stop
                }
                
                debugPrint("Lost discovery: \(lostDiscovery)")
                
                weakSelf.peripherals = discoveries
                weakSelf.tableView.reloadData()
                
                return .continue
        }) { (discoveries, error) in
            if let error = error {
                debugPrint("Scan stopped with error: \(error.localizedDescription)")
            }
            else {
                debugPrint("Scan stopped without error.")
            }
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return peripherals.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "peripheralCell", for: indexPath)
        
        cell.textLabel?.text = peripherals[indexPath.row].peripheralName ?? "Unknown"
        cell.detailTextLabel?.text = "RSSI: \(peripherals[indexPath.row].rssi)"
        
        return cell
    }
    
}

extension ScanEverythingViewController: ConnectionObserver {
    
    func bluetoothAvailable(_ available: Bool) {
        if available && !bluejay.isScanning {
            startScanning()
        }
    }
    
}
