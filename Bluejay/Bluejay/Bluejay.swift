//
//  Bluejay.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-03.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import CoreBluetooth

/**
 Bluejay is a simple wrapper around CoreBluetooth that focuses on making a common usage case as straight forward as possible: a single connected peripheral that the user is interacting with regularly (think most personal electronics devices that have an associated iOS app: fitness trackers, etc).
 
 It also supports a few other niceties for simplifying usage, including automatic discovery of characteristics as they are used, as well as supporting a background task mode where the interaction with the device can be written as synchronous calls running on a background thread to avoid callback pyramids of death, or heavily chained promises.
 */
public class Bluejay: NSObject {
    
    public static let shared = Bluejay()
    
    // MARK: - Private Properties
    
    /// Internal reference to CoreBluetooth's CBCentralManager.
    fileprivate var cbCentralManager: CBCentralManager!
    
    /// List of weak references to objects interested in receiving Bluejay's Bluetooth event callbacks.
    fileprivate var observers: [WeakConnectionObserver] = []
    
    /// Reference to a peripheral that is still connecting. If this is nil, then the peripheral should either be disconnected or connected. This is used to help determine the state of the peripheral's connection.
    fileprivate var connectingPeripheral: Peripheral?
    
    /// Reference to a peripheral that is connected. If this is nil, then the peripheral should either be disconnected or still connecting. This is used to help determine the state of the peripheral's connection.
    fileprivate var connectedPeripheral: Peripheral?
    
    /// Internal state allowing or disallowing reconnection attempts upon a disconnection. It should always be set to true, unless there is a manual and explicit disconnection request that is not caused by an error.
    fileprivate var shouldAutoReconnect = true
    
    fileprivate var startupBackgroundTask: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
    fileprivate var peripheralIdentifierToRestore: PeripheralIdentifier?
    fileprivate var listenRestorer: WeakListenRestorer?
    fileprivate var shouldRestoreState = false
    
    // MARK: - Public Properties
    
    /// Helps distinguish one Bluejay instance from another.
    public var uuid = UUID()
    
    /// Allows checking whether the device's Bluetooth is powered on.
    public var isBluetoothAvailable: Bool {
        return cbCentralManager.state == .poweredOn
    }
    
    /// Allows checking whether Bluejay is currently connecting to a peripheral.
    public var isConnecting: Bool {
        return connectingPeripheral != nil
    }
    
    /// Allows checking whether Bluejay is currently connected to a peripheral.
    public var isConnected: Bool {
        return connectedPeripheral != nil
    }
    
    /// Allows checking whether Bluejay is currently disconnecting from a peripheral.
    public var isDisconnecting: Bool = false
    
    /// Allows checking whether Bluejay is currently scanning.
    public var isScanning: Bool {
        return cbCentralManager.isScanning
    }
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        
        shouldRestoreState = UIApplication.shared.applicationState == .background
        
        if shouldRestoreState {
            debugPrint("Begin startup background task for restoring CoreBluetooth.")
            startupBackgroundTask = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
        }
    }
    
    public func start(
        connectionObserver observer: ConnectionObserver? = nil,
        listenRestorer restorer: ListenRestorer? = nil,
        enableBackgroundMode backgroundMode: Bool = false
        )
    {
        register(observer: Queue.shared)
        
        if let observer = observer {
            register(observer: observer)
        }
        
        if let restorer = restorer {
            listenRestorer = WeakListenRestorer(weakReference: restorer)
        }
        
        var options: [String : Any] = [CBCentralManagerOptionShowPowerAlertKey : false]
        
        if backgroundMode {
            options[CBCentralManagerOptionRestoreIdentifierKey] = "Bluejay"
        }
        
        cbCentralManager = CBCentralManager(
            delegate: self,
            queue: DispatchQueue.main,
            options: options
        )
    }
    
    // MARK: - Events Registration
    
    public func register(observer: ConnectionObserver) {
        observers = observers.filter { $0.weakReference != nil && $0.weakReference !== observer }
        observers.append(WeakConnectionObserver(weakReference: observer))
        
        if cbCentralManager == nil {
            observer.bluetoothAvailable(false)
        }
        else {
            observer.bluetoothAvailable(cbCentralManager.state == .poweredOn)
        }
        
        if let connectedPeripheral = connectedPeripheral {
            observer.connected(connectedPeripheral)
        }
    }
    
    public func unregister(observer: ConnectionObserver) {
        observers = observers.filter { $0.weakReference != nil && $0.weakReference !== observer }
    }
    
    // MARK: - Scanning
    
    public func scan(
        duration: TimeInterval = 0,
        allowDuplicates: Bool = false,
        serviceIdentifiers: [ServiceIdentifier]?,
        discovery: @escaping (ScanDiscovery, [ScanDiscovery]) -> ScanAction,
        expired: ((ScanDiscovery, [ScanDiscovery]) -> ScanAction)? = nil,
        stopped: @escaping ([ScanDiscovery], Swift.Error?) -> Void
        )
    {
        let scanOperation = Scan(
            duration: duration,
            allowDuplicates: allowDuplicates,
            serviceIdentifiers: serviceIdentifiers,
            discovery: discovery,
            expired: expired,
            stopped: stopped,
            manager: cbCentralManager
        )
        
        Queue.shared.add(scan: scanOperation)
    }
    
    public func stopScanning() {
        cbCentralManager.stopScan()
        Queue.shared.stopScanning(Error.cancelledError())
    }
    
    // MARK: - Connection
    
    public func cancelAllConnections() {
        let connected = connectedPeripheral
        let connecting = connectedPeripheral
        
        self.connectingPeripheral = nil
        self.connectedPeripheral = nil
        
        if !cbCentralManager.isScanning {
            connected?.cancelAllOperations(Error.unexpectedDisconnectError())
            connecting?.cancelAllOperations(Error.unexpectedDisconnectError())
            
            Queue.shared.cancelAll(Error.unexpectedDisconnectError())
        }
        
        for observer in observers {
            observer.weakReference?.disconected()
        }
    }
    
    /// Attempt to connect directly to a known peripheral.
    public func connect(_ peripheralIdentifier: PeripheralIdentifier, completion: @escaping (ConnectionResult) -> Void) {
        // Block a connect request when restoring, restore should result in the peripheral being automatically connected.
        if (shouldRestoreState) {
            // Cache requested connect, in case restore messes up unexpectedly.
            peripheralIdentifierToRestore = peripheralIdentifier
            return
        }
        
        if let cbPeripheral = cbCentralManager.retrievePeripherals(withIdentifiers: [peripheralIdentifier.uuid]).first {
            connectingPeripheral = Peripheral(bluejay: self, cbPeripheral: cbPeripheral)
            Queue.shared.add(connection: Connection(peripheral: cbPeripheral, manager: cbCentralManager, callback: completion))
        }
        else {
            completion(.failure(Error.unknownPeripheralError(peripheralIdentifier)))
        }
    }
    
    /// Disconnect the currently connected peripheral.
    public func disconnect(completion: ((Bool)->Void)? = nil) {
        if isDisconnecting {
            return
        }
        
        if let peripheralToDisconnect = connectedPeripheral {
            isDisconnecting = true
            shouldAutoReconnect = false
            
            peripheralToDisconnect.cancelAllOperations(Error.cancelledError())
            
            Queue.shared.add(connection: Disconnection(peripheral: peripheralToDisconnect.cbPeripheral, manager: cbCentralManager, callback: { (result) in
                switch result {
                case .success(let peripheral):
                    debugPrint("Disconnected from \(String(describing: peripheral.name)).")
                    self.isDisconnecting = false
                    
                    completion?(true)
                case .failure(let error):
                    debugPrint("Failed to disconnect with error: \(error.localizedDescription)")
                    self.isDisconnecting = false
                    
                    completion?(false)
                }
            }))
        }
        else {
            debugPrint("Cannot disconnect: there is no connected peripheral.")
            isDisconnecting = false
            
            completion?(false)
        }
    }
    
    // MARK: - Actions
    
    /// Read from a specified characteristic.
    public func read<R: Receivable>(from characteristicIdentifier: CharacteristicIdentifier, completion: @escaping (ReadResult<R>) -> Void) {
        if let peripheral = connectedPeripheral {
            peripheral.read(from: characteristicIdentifier, completion: completion)
        }
        else {
            debugPrint("Could not read characteristic \(characteristicIdentifier.uuid.uuidString): Peripheral is not connected.")
            completion(.failure(Error.notConnectedError()))
        }
    }
    
    /// Write to a specified characteristic.
    public func write<S: Sendable>(to characteristicIdentifier: CharacteristicIdentifier, value: S, completion: @escaping (WriteResult) -> Void) {
        if let peripheral = connectedPeripheral {
            peripheral.write(to: characteristicIdentifier, value: value, completion: completion)
        }
        else {
            debugPrint("Could not write to characteristic \(characteristicIdentifier.uuid.uuidString): Peripheral is not connected.")
            completion(.failure(Error.notConnectedError()))
        }
    }
    
    /// Listen for notifications on a specified characteristic.
    public func listen<R: Receivable>(to characteristicIdentifier: CharacteristicIdentifier, completion: @escaping (ReadResult<R>) -> Void) {
        if let peripheral = connectedPeripheral {
            peripheral.listen(to: characteristicIdentifier, completion: completion)
        }
        else {
            debugPrint("Could not listen to characteristic \(characteristicIdentifier.uuid.uuidString): Peripheral is not connected.")
            completion(.failure(Error.notConnectedError()))
        }
    }
    
    /// End listening on a specified characteristic.
    public func endListen(to characteristicIdentifier: CharacteristicIdentifier, completion: ((WriteResult) -> Void)? = nil) {
        if let peripheral = connectedPeripheral {
            peripheral.endListen(to: characteristicIdentifier, sendFailure: true, completion: completion)
        }
        else {
            debugPrint("Could not end listen to characteristic \(characteristicIdentifier.uuid.uuidString): Peripheral is not connected.")
            completion?(.failure(Error.notConnectedError()))
        }
    }
    
    /// Restore a (beleived to be) active listening session, so if we start up in response to a notification, we can receivie it.
    public func restoreListen<R: Receivable>(to characteristicIdentifier: CharacteristicIdentifier, completion: @escaping (ReadResult<R>) -> Void) {
        if let peripheral = connectedPeripheral {
            peripheral.restoreListen(to: characteristicIdentifier, completion: completion)
        }
        else {
            debugPrint("Could not restore listen to characteristic \(characteristicIdentifier.uuid.uuidString): Peripheral is not connected.")
            completion(.failure(Error.notConnectedError()))
        }
    }
    
    /**
     Run a background task using a syncrounous interface to the Bluetooth device.
     
     - Warning
     Be careful not to access anything that is not thread safe from the background task callbacks.
     */
    public func runTask<Params, Result>(
        _ params: Params,
        backgroundThread: @escaping (SyncPeripheral, Params) throws -> Result,
        mainThread: @escaping (ReadResult<Result>) -> Void)
    {
        if let peripheral = connectedPeripheral {
            DispatchQueue.global().async {
                do {
                    let result = try backgroundThread(SyncPeripheral(parent: peripheral), params)
                    
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
            mainThread(.failure(Error.notConnectedError()))
        }
    }
    
    public func async<Result>(
        jobs: @escaping (SyncPeripheral) throws -> Result,
        completionOnMainThread: @escaping (ReadResult<Result>) -> Void)
    {
        if let peripheral = connectedPeripheral {
            DispatchQueue.global().async {
                do {
                    let result = try jobs(SyncPeripheral(parent: peripheral))
                    
                    DispatchQueue.main.async {
                        completionOnMainThread(.success(result))
                    }
                }
                catch let error as NSError {
                    DispatchQueue.main.async {
                        completionOnMainThread(.failure(error))
                    }
                }
            }
        }
        else {
            completionOnMainThread(.failure(Error.notConnectedError()))
        }
    }
    
}

// MARK: - CBCentralManagerDelegate

extension Bluejay: CBCentralManagerDelegate {
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if #available(iOS 10.0, *) {
            debugPrint("State updated: \(central.state.string())")
        } else {
            // Fallback on earlier versions
        }
        
        if central.state == .poweredOn && connectedPeripheral != nil {
            attemptListenRestoration()
        }
        
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
            
            if connectedPeripheral != nil {
                observer.weakReference?.connected(connectedPeripheral!)
            }
            else {
                observer.weakReference?.disconected()
            }
        }
        
        UIApplication.shared.endBackgroundTask(backgroundTask)
    }
    
    private func attemptListenRestoration() {
        debugPrint("Starting listen restoration.")
        
        guard
            let listenCaches = UserDefaults.standard.dictionary(forKey: Constant.listenCaches),
            let listenCache = listenCaches[uuid.uuidString] as? ListenCache
        else {
            debugPrint("No listens to restore.")
            return
        }
        
        debugPrint("Listen cache to restore: \(listenCache)")
        
        for (serviceUUID, characteristicUUID) in listenCache {
            let serviceIdentifier = ServiceIdentifier(uuid: serviceUUID)
            let characteristicIdentifier = CharacteristicIdentifier(uuid: characteristicUUID, service: serviceIdentifier)
            
            if let listenRestorer = listenRestorer?.weakReference {
                if !listenRestorer.willRestoreListen(on: characteristicIdentifier) {
                    endListen(to: characteristicIdentifier)
                }
            }
            else {
                // If there is no listen restorable delegate, end all active listening.
                endListen(to: characteristicIdentifier)
            }
        }
        
        debugPrint("Listen restoration finished.")
    }
    
    public func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        debugPrint("Will restore state.")
        
        shouldRestoreState = false
        
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
        
        let peripheral = Peripheral(bluejay: self, cbPeripheral: cbPeripheral)
        
        precondition(peripherals.count == 1, "Invalid number of peripheral to restore.")
        
        debugPrint("Peripheral state to restore: \(cbPeripheral.state.string())")
        
        switch cbPeripheral.state {
        case .connecting:
            precondition(connectedPeripheral == nil,
                         "Connected peripheral is not nil during willRestoreState for state: connecting.")
            connectingPeripheral = peripheral
        case .connected:
            precondition(connectingPeripheral == nil,
                         "Connecting peripheral is not nil during willRestoreState for state: connected.")
            connectedPeripheral = peripheral
        case .disconnecting:
            precondition(connectingPeripheral == nil,
                         "Connecting peripheral is not nil during willRestoreState for state: disconnecting.")
            connectedPeripheral = peripheral
        case .disconnected:
            precondition(connectingPeripheral == nil && connectedPeripheral == nil,
                         "Connecting and connected peripherals are not nil during willRestoreState for state: disconnected.")
        }
        
        debugPrint("State restoration finished.")
        
        if startupBackgroundTask != UIBackgroundTaskInvalid {
            debugPrint("Cancelling startup background task.")
            UIApplication.shared.endBackgroundTask(startupBackgroundTask)
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let backgroundTask =  UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
        
        debugPrint("Did connect to: \(peripheral.name ?? peripheral.identifier.uuidString)")

        connectedPeripheral = connectingPeripheral
        connectingPeripheral = nil
        
        // Do not notify observers if this connection is part of a scan operation, as the connection to the peripheral is only for inspection purposes.
        if !Queue.shared.isScanning() {
            for observer in observers {
                observer.weakReference?.connected(connectedPeripheral!)
            }
            
            shouldAutoReconnect = true
        }
        
        Queue.shared.process(event: .didConnectPeripheral(peripheral), error: nil)
        
        UIApplication.shared.endBackgroundTask(backgroundTask)
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Swift.Error?) {
        let backgroundTask =  UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
        
        let peripheralString = peripheral.name ?? peripheral.identifier.uuidString
        let errorString = error?.localizedDescription ?? ""
        
        debugPrint("Did disconnect from: \(peripheralString) with error: \(errorString)")
        
        if !Queue.shared.isEmpty() {
            Queue.shared.process(event: .didDisconnectPeripheral(peripheral), error: nil)
        }
        
        if connectingPeripheral == nil && connectedPeripheral == nil {
            debugPrint("Disconnection is either bogus or already handled, Bluejay has no connected peripheral.")
            return
        }
        
        cancelAllConnections()
        
        debugPrint("Should auto-reconnect: \(self.shouldAutoReconnect)")
        
        if shouldAutoReconnect {
            debugPrint("Issuing reconnect to: \(peripheral.name ?? peripheral.identifier.uuidString)")
            connect(PeripheralIdentifier(uuid: peripheral.identifier), completion: {_ in })
        }
        
        UIApplication.shared.endBackgroundTask(backgroundTask)
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Swift.Error?) {
        let peripheralString = peripheral.name ?? peripheral.identifier.uuidString
        let errorString = error?.localizedDescription ?? ""
        
        debugPrint("Did fail to connect to: \(peripheralString) with error: \(errorString)")
        
        // Use the same clean up logic provided in the did disconnect callback.
        centralManager(central, didDisconnectPeripheral: peripheral, error: error)
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let peripheralString = advertisementData[CBAdvertisementDataLocalNameKey] ?? peripheral.identifier.uuidString
        
        debugPrint("Did discover: \(peripheralString)")
        
        Queue.shared.process(event: .didDiscoverPeripheral(peripheral, advertisementData, RSSI), error: nil)
    }
    
}
