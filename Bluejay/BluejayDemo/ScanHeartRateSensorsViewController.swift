//
//  ScanHeartRateSensorsViewController.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-05-15.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import UIKit
import Bluejay

class ScanHeartRateSensorsViewController: UITableViewController {
    
    fileprivate let bluejay = Bluejay()
    
    private var peripherals = [ScanDiscovery]() {
        didSet {
            peripherals.sort { (a, b) -> Bool in
                return a.rssi < b.rssi
            }
        }
    }
    
    private var selectedPeripheralIdentifier: PeripheralIdentifier?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        clearsSelectionOnViewWillAppear = true
        
        bluejay.start(connectionObserver: self, backgroundRestore: .enableWithListenRestorer("com.steamclock.bluejay", self))
        
        scanHeartSensors()
    }
    
    fileprivate func scanHeartSensors() {
        let heartRateService = ServiceIdentifier(uuid: "180D")
        
        bluejay.scan(
            allowDuplicates: true,
            serviceIdentifiers: [heartRateService],
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
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if bluejay.isConnecting || bluejay.isConnected {
            bluejay.disconnect(completion: { [weak self] (result) in
                guard let weakSelf = self else {
                    return
                }
                
                switch result {
                case .success:
                    if !weakSelf.bluejay.isScanning {
                        DispatchQueue.main.async {
                            weakSelf.scanHeartSensors()
                        }
                    }
                case .cancelled:
                    preconditionFailure("Disconnection cancelled unexpectedly.")
                case .failure(let error):
                    preconditionFailure("Disconnection failed with error: \(error.localizedDescription)")
                }
            })
        }
        else if !bluejay.isScanning {
            scanHeartSensors()
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return peripherals.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "heartCell", for: indexPath)
        
        cell.textLabel?.text = peripherals[indexPath.row].peripheral.name ?? "Unknown"
        cell.detailTextLabel?.text = "RSSI: \(peripherals[indexPath.row].rssi)"
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let peripheral = peripherals[indexPath.row].peripheral
        
        let peripheralIdentifier = PeripheralIdentifier(uuid: peripheral.identifier)
        
        bluejay.connect(peripheralIdentifier) { [weak self] (result) in
            switch result {
            case .success(let peripheral):
                debugPrint("Connection to \(peripheral.identifier) successful.")
                
                guard let weakSelf = self else {
                    return
                }
                
                weakSelf.selectedPeripheralIdentifier = peripheralIdentifier
                
                weakSelf.performSegue(withIdentifier: "showHeartSensor", sender: self)
            case .cancelled:
                debugPrint("Connection to \(peripheral.identifier) cancelled.")
            case .failure(let error):
                debugPrint("Connection to \(peripheral.identifier) failed with error: \(error.localizedDescription)")
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showHeartSensor" {
            let destination = segue.destination as! HeartSensorViewController
            destination.bluejay = bluejay
            destination.peripheralIdentifier = selectedPeripheralIdentifier
        }
    }
}

extension ScanHeartRateSensorsViewController: ConnectionObserver {
    
    func bluetoothAvailable(_ available: Bool) {
        debugPrint("Bluetooth available: \(available)")
        
        if available && !bluejay.isScanning {
            scanHeartSensors()
        }
    }
    
    func connected(_ peripheral: Peripheral) {
        debugPrint("Connected to \(peripheral)")
    }
    
    func disconnected() {
        debugPrint("Disconnected")
    }
    
}

extension ScanHeartRateSensorsViewController: ListenRestorer {
    
    func willRestoreListen(on characteristic: CharacteristicIdentifier) -> Bool {
        return false
    }
    
}

