//
//  Scan.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-18.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import CoreBluetooth

private let deviceInfoService = ServiceIdentifier(uuid: "180A")
private let serialNumberCharacteristic = CharacteristicIdentifier(uuid: "2A25", service: deviceInfoService)

class Scan: Queueable {
    
    var state = OperationState.notStarted
    var manager: CBCentralManager
    
    private let duration: TimeInterval
    private let allowDuplicates: Bool
    private let serviceIdentifiers: [ServiceIdentifier]?
    private let discovery: (ScanDiscovery, [ScanDiscovery]) -> (ScanAction)
    private let stopped: ([ScanDiscovery], Swift.Error?) -> Void
    
    private var discoveries = [ScanDiscovery]()
    
    init(duration: TimeInterval,
         allowDuplicates: Bool,
         serviceIdentifiers: [ServiceIdentifier]?,
         discovery: @escaping (ScanDiscovery, [ScanDiscovery]) -> (ScanAction),
         stopped: @escaping ([ScanDiscovery], Swift.Error?) -> Void,
         manager: CBCentralManager)
    {
        self.duration = duration
        self.allowDuplicates = allowDuplicates
        self.serviceIdentifiers = serviceIdentifiers
        self.discovery = discovery
        self.stopped = stopped
        self.manager = manager
    }
    
    func start() {
        log.debug("Starting operation: Scan")
        
        state = .running
        
        let services = serviceIdentifiers?.map({ (element) -> CBUUID in
            return element.uuid
        })
        
        manager.scanForPeripherals(withServices: services, options: [CBCentralManagerScanOptionAllowDuplicatesKey : allowDuplicates])
    }
    
    func process(event: Event) {
        log.debug("Processing operation: Scan")
        
        if case .didDiscoverPeripheral(let peripheral, let advertisementData, let rssi) = event {
            let newDiscovery = ScanDiscovery(peripheral: peripheral, advertisementPacket: advertisementData, rssi: rssi.intValue)
            
            if let indexOfExistingDiscovery = discoveries.index(where: { (existingDiscovery) -> Bool in
                return existingDiscovery.peripheral.identifier == peripheral.identifier
            })
            {
                let existingDiscovery = discoveries[indexOfExistingDiscovery]
                
                // Ignore discovery if RSSI change is insignificant.
                if abs(existingDiscovery.rssi - rssi.intValue) < 5 {
                    return
                }
                
                // Update existing discovery.
                discoveries.remove(at: indexOfExistingDiscovery)
                discoveries.insert(newDiscovery, at: indexOfExistingDiscovery)
            }
            else {
                discoveries.append(newDiscovery)
            }
            
            if discovery(newDiscovery, discoveries) == .stop {
                manager.stopScan()
                state = .completed
                
                stopped(discoveries, nil)
            }
        }
        else {
            preconditionFailure("Unexpected event response: \(event)")
        }
    }
    
    func fail(_ error : NSError) {
        manager.stopScan()
        state = .failed(error)
        
        stopped(discoveries, error)
    }
    
}
