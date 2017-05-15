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
    
    var queue: Queue?
    var state: QueueableState
    
    private let manager: CBCentralManager
    
    private let duration: TimeInterval
    private let allowDuplicates: Bool
    private let serviceIdentifiers: [ServiceIdentifier]?
    private let discovery: (ScanDiscovery, [ScanDiscovery]) -> ScanAction
    private let expired: ((ScanDiscovery, [ScanDiscovery]) -> ScanAction)?
    private let stopped: ([ScanDiscovery], Swift.Error?) -> Void
    
    private var discoveries = [ScanDiscovery]()
    private var blacklist = [ScanDiscovery]()
    private var timers = [(UUID, Timer)]()
    
    init(duration: TimeInterval,
         allowDuplicates: Bool,
         serviceIdentifiers: [ServiceIdentifier]?,
         discovery: @escaping (ScanDiscovery, [ScanDiscovery]) -> ScanAction,
         expired: ((ScanDiscovery, [ScanDiscovery]) -> ScanAction)?,
         stopped: @escaping ([ScanDiscovery], Swift.Error?) -> Void,
         manager: CBCentralManager)
    {
        self.state = .notStarted
        
        self.duration = duration
        self.allowDuplicates = allowDuplicates
        self.serviceIdentifiers = serviceIdentifiers
        self.discovery = discovery
        self.expired = expired
        self.stopped = stopped
        self.manager = manager
    }
        
    func start() {        
        state = .running
        
        let services = serviceIdentifiers?.map({ (element) -> CBUUID in
            return element.uuid
        })
        
        manager.scanForPeripherals(withServices: services, options: [CBCentralManagerScanOptionAllowDuplicatesKey : allowDuplicates])
        
        log("Started scanning.")
    }
    
    func process(event: Event) {
        if case .didDiscoverPeripheral(let peripheral, let advertisementData, let rssi) = event {
            let newDiscovery = ScanDiscovery(peripheral: peripheral, advertisementPacket: advertisementData, rssi: rssi.intValue)
            
            // Ignore discovery if it is blacklisted.
            if blacklist.contains(where: { (blacklistedDiscovery) -> Bool in
                return newDiscovery.peripheral.identifier == blacklistedDiscovery.peripheral.identifier
            })
            {
                return
            }
            
            // Exit function early if discovery is to be blacklisted.
            if discovery(newDiscovery, discoveries) == .blacklist {
                blacklist.append(newDiscovery)
                return
            }
            
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
                
                log("Finished scanning.")
                
                stopped(discoveries, nil)
                
                updateQueue()
            }
        }
        else {
            preconditionFailure("Unexpected event response: \(event)")
        }
    }
    
    func cancel() {
        cancelled()
    }
    
    func cancelled() {
        state = .cancelled
        
        clearTimers()
        manager.stopScan()
        
        log("Cancelled scanning.")
        
        stopped(discoveries, nil)
        
        updateQueue()
    }
    
    func fail(_ error : NSError) {
        state = .failed(error)

        clearTimers()        
        manager.stopScan()
        
        log("Failed scanning with error: \(error.localizedDescription).")
        
        stopped(discoveries, error)
        
        updateQueue()
    }
    
    private func refreshTimer(identifier: UUID) {
        if let indexOfExistingTimer = timers.index(where: { (uuid, timer) -> Bool in
            return uuid == identifier
        })
        {
            timers[indexOfExistingTimer].1.invalidate()
            timers.remove(at: indexOfExistingTimer)
        }
        
        var timer: Timer?
        
        if #available(iOS 10.0, *) {
            timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { [weak self] (timer) in
                guard let weakSelf = self else {
                    return
                }
                weakSelf.refresh(identifier: identifier)
            }
        } else {
            // Fallback on earlier versions
            timer = Timer.scheduledTimer(
                timeInterval: 15,
                target: self,
                selector: #selector(refresh(timer:)),
                userInfo: identifier,
                repeats: false
            )
        }
        
        timers.append((identifier, timer!))
    }
    
    private func refresh(identifier: UUID) {
        if state.isFinished {
            return
        }
        
        if let indexOfExpiredDiscovery = discoveries.index(where: { (discovery) -> Bool in
            return discovery.peripheral.identifier == identifier
        })
        {
            let expiredDiscovery = discoveries[indexOfExpiredDiscovery]
            discoveries.remove(at: indexOfExpiredDiscovery)
            
            if expired?(expiredDiscovery, discoveries) == .stop {
                DispatchQueue.main.async {
                    self.clearTimers()
                    
                    self.manager.stopScan()
                    self.state = .completed
                    
                    self.stopped(self.discoveries, nil)
                }
            }
        }
    }
    
    @objc func refresh(timer: Timer) {
        let identifier = timer.userInfo as! UUID
        refresh(identifier: identifier)
    }
    
    private func clearTimers() {
        for timer in timers {
            timer.1.invalidate()
        }
        
        timers = []
    }
    
}
