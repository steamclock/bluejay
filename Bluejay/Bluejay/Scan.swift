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

/// A scan operation.
class Scan: Queueable {
    
    /// The queue this operation belongs to.
    var queue: Queue?
    
    /// The state of this operation.
    var state: QueueableState
    
    /// The manager responsible for this operation.
    private let manager: CBCentralManager
    
    /// The duration of the scan.
    private let duration: TimeInterval
    
    /// If allowDuplicates is true, the scan will repeatedly discover the same device as long as its advertisement is picked up. This is a Core Bluetooth option, and it does consume more battery, doesn't work in the background, and is often advised to turn off.
    private let allowDuplicates: Bool
    
    /// The scan will only look for peripherals broadcasting the specified services.
    private let serviceIdentifiers: [ServiceIdentifier]?
    
    /// The discovery callback.
    private let discovery: (ScanDiscovery, [ScanDiscovery]) -> ScanAction
    
    /// The expired callback.
    private let expired: ((ScanDiscovery, [ScanDiscovery]) -> ScanAction)?
    
    /// The stopped callback. Called when stopped normally as well, not just when there is an error.
    private let stopped: ([ScanDiscovery], Error?) -> Void
    
    /// The discoveries made so far in a given scan session.
    private var discoveries = [ScanDiscovery]()
    
    /// The blacklisted discoveries collected so far in a gvien scan session.
    private var blacklist = [ScanDiscovery]()
    
    /// The timers used to estimate an expiry callback, indicating that the peripheral is potentially no longer accessible.
    private var timers = [(UUID, Timer)]()
    
    init(duration: TimeInterval,
         allowDuplicates: Bool,
         serviceIdentifiers: [ServiceIdentifier]?,
         discovery: @escaping (ScanDiscovery, [ScanDiscovery]) -> ScanAction,
         expired: ((ScanDiscovery, [ScanDiscovery]) -> ScanAction)?,
         stopped: @escaping ([ScanDiscovery], Error?) -> Void,
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
        
        if allowDuplicates {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(didEnterBackgroundWithAllowDuplicates),
                name: NSNotification.Name.UIApplicationDidEnterBackground,
                object: nil
            )
        }
        
        if serviceIdentifiers == nil {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(didEnterBackgroundWithoutServiceIdentifiers),
                name: NSNotification.Name.UIApplicationDidEnterBackground,
                object: nil
            )
        }
        
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
            if case .blacklist = discovery(newDiscovery, discoveries) {
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
            
            if case .stop = discovery(newDiscovery, discoveries) {
                state = .completed

                log("Finished scanning.")

                stopScan(with: discoveries, error: nil)
            }
            else if case .connect(let discovery, let completion) = discovery(newDiscovery, discoveries) {
                state = .completed
                
                log("Finished scanning.")

                stopScan(with: discoveries, error: nil)
                
                if let queue = queue {
                    if let cbPeripheral = manager.retrievePeripherals(withIdentifiers: [discovery.peripheral.identifier]).first {
                        queue.add(Connection(peripheral: cbPeripheral, manager: manager, callback: completion))
                    }
                    else {
                        completion(.failure(BluejayError.unexpectedPeripheral(PeripheralIdentifier(uuid: discovery.peripheral.identifier))))
                    }
                }
                else {
                    preconditionFailure("Could not connect at the end of a scan: queue is nil.")
                }
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
        
        log("Cancelled scanning.")

        stopScan(with: discoveries, error: nil)
    }
    
    func fail(_ error : Error) {
        state = .failed(error)
        
        log("Failed scanning with error: \(error.localizedDescription)")
        
        stopScan(with: discoveries, error: error)
    }
    
    @objc func didEnterBackgroundWithAllowDuplicates() {
        fail(BluejayError.scanningWithAllowDuplicatesInBackgroundNotSupported)
    }
    
    @objc func didEnterBackgroundWithoutServiceIdentifiers() {
        fail(BluejayError.missingServiceIdentifiersInBackground)
    }
    
    private func stopScan(with discoveries: [ScanDiscovery], error: Error?) {
        clearTimers()
        
        // There is no point trying to stop the scan if the error is due to the manager being powered off, as trying to do so has no effect and will also cause CoreBluetooth to log an "API MISUSE" warning.
        if manager.state == .poweredOn {
            manager.stopScan()
        }
        
        stopped(discoveries, error)
        
        NotificationCenter.default.removeObserver(self)
        
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
            
            if let expired = expired {
                if case .stop = expired(expiredDiscovery, discoveries) {
                    DispatchQueue.main.async {
                        self.clearTimers()
                        
                        self.manager.stopScan()
                        self.state = .completed
                        
                        self.stopped(self.discoveries, nil)
                    }
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
