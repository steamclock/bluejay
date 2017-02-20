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
    
    private let serviceIdentifier: ServiceIdentifier
    private let serialNumber: String?
    private var callback: ((ScanResult) -> Void)?
    
    private var scannedPeripherals = [(CBPeripheral, [String : Any])]()

    static var blacklist = [CBPeripheral]()
    
    init(serviceIdentifier: ServiceIdentifier, serialNumber: String? = nil, manager: CBCentralManager, callback: @escaping ((ScanResult) -> Void)) {
        self.serviceIdentifier = serviceIdentifier
        self.serialNumber = serialNumber
        self.manager = manager
        self.callback = callback
    }
    
    func start() {
        log.debug("Starting operation: Scan")
        
        state = .running
        
        manager.scanForPeripherals(withServices: [serviceIdentifier.uuid], options: [CBCentralManagerScanOptionAllowDuplicatesKey : false])
    }
    
    func process(event: Event) {
        log.debug("Processing operation: Scan")
        
        if case .didDiscoverPeripheral(let peripheral, let advertisementData) = event {
            // Remove duplicates.
            scannedPeripherals = scannedPeripherals.filter({ (scannedPeripheral) -> Bool in
                return scannedPeripheral.0.identifier != peripheral.identifier
            })
            
            scannedPeripherals.append(peripheral, advertisementData)
            
            if serialNumber != nil {
                log.debug("Attempting to match serial number.")
                
                if Scan.blacklist.contains(where: { (blacklistedPeripheral) -> Bool in
                    return blacklistedPeripheral.identifier == peripheral.identifier
                }) {
                    log.debug("Serial number does not match, blacklisted peripheral.")
                    return
                }
                else {
                    manager.stopScan()
                    state = .completed
                    
                    match(
                        serviceIdentifier: serviceIdentifier,
                        serialNumber: serialNumber!,
                        to: peripheral,
                        with: advertisementData,
                        callback: callback!
                        )
                }
            }
            else {
                manager.stopScan()
                state = .completed
                
                callback?(.success(scannedPeripherals))
            }
        }
        else {
            preconditionFailure("Unexpected event response: \(event)")
        }
    }
    
    func fail(_ error : NSError) {
        manager.stopScan()
        state = .failed(error)
        
        callback?(.failure(error))
        callback = nil
    }
    
    private func match(
        serviceIdentifier: ServiceIdentifier,
        serialNumber: String,
        to peripheral: CBPeripheral,
        with advertisementData: [String : Any],
        callback: @escaping ((ScanResult) -> Void))
    {
        Bluejay.shared.connect(PeripheralIdentifier(uuid: peripheral.identifier), completion: { (result) in
            switch result {
            case .success(_):
                Bluejay.shared.read(from: serialNumberCharacteristic, completion: { (result: ReadResult<String>) in
                    switch result {
                    case .success(let value):
                        if value == serialNumber {
                            log.debug("Serial number matches.")
                            
                            Scan.blacklist = []
                            
                            callback(.success([(peripheral, advertisementData)]))
                        }
                        else {
                            log.debug("Serial number does not match.")
                            
                            Scan.blacklist.append(peripheral)
                            
                            Bluejay.shared.disconnect() { isDisconnectionSuccessful in
                                if isDisconnectionSuccessful {
                                    Bluejay.shared.scan(
                                        serviceIdentifier: serviceIdentifier,
                                        serialNumber: serialNumber,
                                        completion: callback
                                    )
                                }
                            }
                        }
                    case .failure(let error):
                        log.debug("Failed to match serial number with error: \(error.localizedDescription)")
                        
                        Scan.blacklist.append(peripheral)
                        
                        Bluejay.shared.disconnect() { isDisconnectionSuccessful in
                            if isDisconnectionSuccessful {
                                Bluejay.shared.scan(
                                    serviceIdentifier: serviceIdentifier,
                                    serialNumber: serialNumber,
                                    completion: callback
                                )
                            }
                        }
                    }
                })
            case .failure(let error):
                log.debug("Failed to match serial number with error: \(error.localizedDescription)")
            }
        })
    }
    
}
