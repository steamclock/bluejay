//
//  Bluejay.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-03.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import CoreBluetooth

private var standardConnectOptions: [String : AnyObject] = [
    CBConnectPeripheralOptionNotifyOnDisconnectionKey: true as AnyObject,
    CBConnectPeripheralOptionNotifyOnConnectionKey: true as AnyObject
]

/**
    Bluejay is a simple wrapper around CoreBluetooth that focuses on making a common usage case as striaghtforward as possible: a single 'paired' peripheral that the user is interacting with regularly (think most personal electronics devices that have an associated iPhone app: fitness trackers, etc).

    It also supports a few other niceties for simplifying usage, including automatic discovery of characteristics as they are used, as well as supporting a background task mode where the interaction with the device can be written as synchronous calls running on a background thread to avoid callback pyramids of death, or heavily chained promises.
*/
public class Bluejay: NSObject {
    
    // MARK: - Properties
    
    fileprivate var cbCentralManager: CBCentralManager!
    
    public var isBluetoothAvailable: Bool {
        return cbCentralManager.state == .poweredOn
    }
    
    fileprivate var observers: [WeakBluejayEventsObservable] = []
    
    fileprivate var connectingPeripheral: BluejayPeripheral?
    fileprivate var connectedPeripheral: BluejayPeripheral?
    
    public var isConnecting: Bool {
        return connectingPeripheral != nil
    }
    
    public var isConnected: Bool {
        return connectedPeripheral != nil
    }
    
    public var shouldAutoReconnect = true
    
    fileprivate var connectionCallback: ((BluejayConnectionResult) -> Void)?
    
    fileprivate var startupBackgroundTask: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
    
    fileprivate var peripheralIdentifierToRestore: PeripheralIdentifier?
    fileprivate var shouldRestore = false
    
    // MARK: - Initialization

    public override init() {
        super.init()
        
        cbCentralManager = CBCentralManager(
            delegate: self,
            queue: DispatchQueue.main,
            options: [
                CBCentralManagerOptionShowPowerAlertKey: false,
                CBCentralManagerOptionRestoreIdentifierKey: "Bluejay"
            ]
        )
    }
    
    // MARK: - Events Registration
    
    public func register(_ observer: BluejayEventsObservable) {
        observers = observers.filter { $0.weakReference != nil && $0.weakReference !== observer }
        observers.append(WeakBluejayEventsObservable(weakReference: observer))
        
        observer.bluetoothAvailable(cbCentralManager.state == .poweredOn)
        
        if let connectedPeripheral = connectedPeripheral {
            observer.connected(connectedPeripheral)
        }
    }
    
    public func unregister(_ observer: BluejayEventsObservable) {
        observers = observers.filter { $0.weakReference != nil && $0.weakReference !== observer }
    }
    
    // MARK: - Scanning
    
    /// Start a scan for devices with the specified service, device will be automatially connected once found
    public func scan(service serviceIdentifier: ServiceIdentifier, completion: @escaping (BluejayConnectionResult) -> Void) {
        precondition(connectionCallback == nil, "Cannot have more than one active scan or connect request.")
        
        connectionCallback = completion
        
        cbCentralManager.scanForPeripherals(withServices: [serviceIdentifier.uuid], options: [CBCentralManagerScanOptionAllowDuplicatesKey : false])
    }
    
    /// Cancel oustanding peripheral scans.
    public func cancelScan() {
        cbCentralManager.stopScan()
    }
    
    // MARK: - Connection
    
    public func cancelAllConnections() {
        let connected = connectedPeripheral
        let connecting = connectedPeripheral
        
        self.connectingPeripheral = nil
        self.connectedPeripheral = nil
        
        connected?.cancelAllOperations(BluejayErrors.unexpectedDisconnectError())
        connecting?.cancelAllOperations(BluejayErrors.unexpectedDisconnectError())
        
        connectionCallback?(.failure(BluejayErrors.unexpectedDisconnectError()))
        connectionCallback = nil
    }
    
    /// Attempt to connect directly to a known peripheral.
    public func connect(_ peripheralIdentifier: PeripheralIdentifier, completion: @escaping (BluejayConnectionResult) -> Void) {
        precondition(connectionCallback == nil, "Cannot have more than one active scan or connect request.")
        
        // Block a connect request when restoring, restore should result in the peripheral being automatically connected.
        if(shouldRestore) {
            // Cache requested connect, in case restore messes up unexpectedly.
            peripheralIdentifierToRestore = peripheralIdentifier
            return
        }
        
        if let cbPeripheral = cbCentralManager.retrievePeripherals(withIdentifiers: [peripheralIdentifier.uuid]).first {
            connectionCallback = completion
            connectingPeripheral = BluejayPeripheral(cbPeripheral: cbPeripheral)
            cbCentralManager.connect(cbPeripheral, options: standardConnectOptions)
        }
        else {
            completion(.failure(BluejayErrors.unknownPeripheralError(peripheralIdentifier)))
        }
    }
    
    /// Disconnect the currently connected peripheral.
    public func disconnect() {
        shouldAutoReconnect = false
        
        if let peripheralToDisconnect = connectedPeripheral {
            connectingPeripheral = nil
            connectedPeripheral = nil
            
            peripheralToDisconnect.cancelAllOperations(BluejayErrors.cancelledError())
            cbCentralManager.cancelPeripheralConnection(peripheralToDisconnect.cbPeripheral)
        }
        
        connectionCallback = nil
    }
    
    // MARK: - Actions
    
    /// Read from a specified characteristic.
    public func read<R: BluejayReceivable>(from characteristicIdentifier: CharacteristicIdentifier, completion: @escaping (BluejayReadResult<R>) -> Void) {
        if let peripheral = connectedPeripheral {
            peripheral.read(from: characteristicIdentifier, completion: completion)
        }
        else {
            completion(.failure(BluejayErrors.notConnectedError()))
        }
    }
    
    /// Write to a specified characteristic.
    public func write<S: BluejaySendable>(to characteristicIdentifier: CharacteristicIdentifier, value: S, completion: @escaping (BluejayWriteResult) -> Void) {
        if let peripheral = connectedPeripheral {
            peripheral.write(to: characteristicIdentifier, value: value, completion: completion)
        }
        else {
            completion(.failure(BluejayErrors.notConnectedError()))
        }
    }
    
    /// Listen for notifications on a specified characteristic.
    public func listen<R: BluejayReceivable>(to characteristicIdentifier: CharacteristicIdentifier, completion: @escaping (BluejayReadResult<R>) -> Void) {
        if let peripheral = connectedPeripheral {
            peripheral.listen(to: characteristicIdentifier, completion: completion)
        }
        else {
            completion(.failure(BluejayErrors.notConnectedError()))
        }
    }
    
    /// Cancel listening on a specified characteristic.
    public func cancelListen(to characteristicIdentifier: CharacteristicIdentifier, completion: ((BluejayWriteResult) -> Void)? = nil) {
        if let peripheral = connectedPeripheral {
            peripheral.cancelListen(to: characteristicIdentifier, sendFailure: true, completion: completion)
        }
        else {
            completion?(.failure(BluejayErrors.notConnectedError()))
        }
    }
    
    /// Restore a (beleived to be) active listening session, so if we start up in response to a notification, we can receivie it.
    public func restoreListen<R: BluejayReceivable>(to characteristicIdentifier: CharacteristicIdentifier, completion: @escaping (BluejayReadResult<R>) -> Void) {
        if let peripheral = connectedPeripheral {
            peripheral.restoreListen(to: characteristicIdentifier, completion: completion)
        }
        else {
            completion(.failure(BluejayErrors.notConnectedError()))
        }
    }
    
    /**
        Run a background task using a syncrounous interface to the Bluetooth device.
     
        - Warning
        Be careful not to access anything that is not thread safe from the background task callbacks.
     */
    public func runTask<Params, Result>(
        _ params: Params,
        backgroundThread: @escaping (BluejaySyncPeripheral, Params) throws -> Result,
        mainThread: @escaping (BluejayReadResult<Result>) -> Void)
    {
        if let peripheral = connectedPeripheral {
            DispatchQueue.global().async {
                do {
                    let result = try backgroundThread(BluejaySyncPeripheral(parent: peripheral), params)
                    
                    DispatchQueue.main.async {
                        mainThread(.success(result))
                    }
                }
                catch let error as NSError {
                    DispatchQueue.main.async {
                        mainThread(.failure(error))
                    }
                }
            }
        }
        else {
            mainThread(.failure(BluejayErrors.notConnectedError()))
        }
    }
    
}

// MARK: - CBCentralManagerDelegate

extension Bluejay: CBCentralManagerDelegate {
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let backgroundTask = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
        
        if central.state == .poweredOff {
            if let connectingPeripheral = connectingPeripheral {
                cbCentralManager.cancelPeripheralConnection(connectingPeripheral.cbPeripheral)
            }
            
            if let connectedPeripheral = connectedPeripheral {
                cbCentralManager.cancelPeripheralConnection(connectedPeripheral.cbPeripheral)
            }
            
            cbCentralManager.stopScan()
            
            cancelAllConnections()
        }
        
        for observer in observers {
            observer.weakReference?.bluetoothAvailable(central.state == .poweredOn)
        }
        
        UIApplication.shared.endBackgroundTask(backgroundTask)
    }
    
    public func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        shouldRestore = false
        
        guard
            let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral],
            let cbPeripheral = peripherals.first
        else {
            // Weird failure case that seems to happen sometime,
            // restoring but don't have a device in the restore list
            // try to trigger a reconnect if we have a stored
            // peripheral
            if let id = peripheralIdentifierToRestore {
                connect(id, completion: { _ in })
            }
            
            return
        }
        
        let peripheral = BluejayPeripheral(cbPeripheral: cbPeripheral)
        
        precondition(peripherals.count == 1)
        
        switch cbPeripheral.state {
        case .connecting:
            precondition(connectedPeripheral == nil, "Connected peripheral is not nil during willRestoreState for state: connecting.")
            connectingPeripheral = peripheral
        case .connected:
            precondition(connectingPeripheral == nil, "Connecting peripheral is not nil during willRestoreState for state: connected.")
            connectedPeripheral = peripheral
        case .disconnecting:
            precondition(connectingPeripheral == nil, "Connecting peripheral is not nil during willRestoreState for state: disconnecting.")
            connectedPeripheral = peripheral
        case .disconnected:
            precondition(connectingPeripheral == nil && connectedPeripheral == nil,
                         "Connecting and connected peripherals are not nil during willRestoreState for state: disconnected.")
        }
        
        if startupBackgroundTask != UIBackgroundTaskInvalid {
            UIApplication.shared.endBackgroundTask(startupBackgroundTask)
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let backgroundTask =  UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
        
        connectedPeripheral = connectingPeripheral
        connectingPeripheral = nil
        
        connectionCallback?(.success(connectedPeripheral!))
        connectionCallback = nil
        
        for observer in observers {
            observer.weakReference?.connected(connectedPeripheral!)
        }
        
        shouldAutoReconnect = true
        
        UIApplication.shared.endBackgroundTask(backgroundTask)
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let backgroundTask =  UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
        
        if connectingPeripheral == nil && connectedPeripheral == nil {
            return
        }
        
        let wasConnected = connectedPeripheral != nil
        
        cancelAllConnections()
        
        if(wasConnected) {
            for observer in observers {
                observer.weakReference?.disconected()
            }
        }
        
        if shouldAutoReconnect {
            connect(PeripheralIdentifier(uuid: peripheral.identifier), completion: {_ in })
        }
        
        UIApplication.shared.endBackgroundTask(backgroundTask)
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        // Use the same clean up logic provided in the did disconnect callback.
        centralManager(central, didDisconnectPeripheral: peripheral, error: error)
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        cbCentralManager.stopScan()
        connectingPeripheral = BluejayPeripheral(cbPeripheral: peripheral)
        cbCentralManager.connect(peripheral, options: standardConnectOptions)
    }
    
}
