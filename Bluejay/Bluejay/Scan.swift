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
    private let discovery: (ScanDiscovery, [ScanDiscovery]) -> ScanAction
    private let expired: ((ScanDiscovery, [ScanDiscovery]) -> ScanAction)?
    private let stopped: ([ScanDiscovery], Swift.Error?) -> Void
    
    private var discoveries = [ScanDiscovery]()
    private var timers = [(UUID, Timer)]()
    
    init(duration: TimeInterval,
         allowDuplicates: Bool,
         serviceIdentifiers: [ServiceIdentifier]?,
         discovery: @escaping (ScanDiscovery, [ScanDiscovery]) -> ScanAction,
         expired: ((ScanDiscovery, [ScanDiscovery]) -> ScanAction)?,
         stopped: @escaping ([ScanDiscovery], Swift.Error?) -> Void,
         manager: CBCentralManager)
    {
        self.duration = duration
        self.allowDuplicates = allowDuplicates
        self.serviceIdentifiers = serviceIdentifiers
        self.discovery = discovery
        self.expired = expired
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
            
            // Only predict losing signals to broadcasting peripherals if allow duplicates is enabled, as that mode is mostly used in monitoring context where we need to keep track of advertising peripherals continously.
            if allowDuplicates {
                refreshTimer(identifier: newDiscovery.peripheral.identifier)
            }
            
            if let indexOfExistingDiscovery = discoveries.index(where: { (existingDiscovery) -> Bool in
                return existingDiscovery.peripheral.identifier == peripheral.identifier
            })
            {
                let existingDiscovery = discoveries[indexOfExistingDiscovery]
                
                // Throttle discovery by ignoring discovery if the change of RSSI is insignificant.
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
                clearTimers()
                
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
        clearTimers()
        
        manager.stopScan()
        state = .failed(error)
        
        stopped(discoveries, error)
    }
    
    private func refreshTimer(identifier: UUID) {
        if let indexOfExistingTimer = timers.index(where: { (uuid, timer) -> Bool in
            return uuid == identifier
        })
        {
            timers[indexOfExistingTimer].1.invalidate()
            timers.remove(at: indexOfExistingTimer)
        }
        
        let timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { [weak self] (timer) in
            guard let weakSelf = self else {
                return
            }
            
            if weakSelf.state.isCompleted {
                return
            }
            else {
                if let indexOfExpiredDiscovery = weakSelf.discoveries.index(where: { (discovery) -> Bool in
                    return discovery.peripheral.identifier == identifier
                })
                {
                    let expiredDiscovery = weakSelf.discoveries[indexOfExpiredDiscovery]
                    weakSelf.discoveries.remove(at: indexOfExpiredDiscovery)
                    
                    if weakSelf.expired?(expiredDiscovery, weakSelf.discoveries) == .stop {
                        DispatchQueue.main.async {
                            weakSelf.clearTimers()
                            
                            weakSelf.manager.stopScan()
                            weakSelf.state = .completed
                            
                            weakSelf.stopped(weakSelf.discoveries, nil)
                        }
                    }
                }
            }
        }
        
        timers.append((identifier, timer))
    }
    
    private func clearTimers() {
        for timer in timers {
            timer.1.invalidate()
        }
        
        timers = []
    }
    
}
