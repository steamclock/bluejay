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
 Bluejay is a simple wrapper around CoreBluetooth that focuses on making a common usage case as straight forward as possible: a single connected peripheral that the user is interacting with regularly (think most personal electronics devices that have an associated iOS app: fitness trackers, guitar amps, etc).
 
 It also supports a few other niceties for simplifying usage, including automatic discovery of characteristics as they are used, as well as supporting a background task mode where the interaction with the device can be written as synchronous calls running on a background thread to avoid callback pyramids of death, or heavily chained promises.
 */
public class Bluejay: NSObject {
    
    // MARK: - Private Properties
    
    /// Internal reference to CoreBluetooth's CBCentralManager.
    fileprivate var cbCentralManager: CBCentralManager!
    
    /// List of weak references to objects interested in receiving Bluejay's Bluetooth event callbacks.
    fileprivate var observers = [WeakConnectionObserver]()
    
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
    
    // MARK: - Internal Properties
    
    /// Contains the operations to execute in FIFO order.
    var queue: Queue!
    
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
    
    public override init() {
        super.init()
        
        shouldRestoreState = UIApplication.shared.applicationState == .background
        
        if shouldRestoreState {
            debugPrint("Begin startup background task for restoring CoreBluetooth.")
            startupBackgroundTask = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
        }
        
        log("Bluejay initialized with UUID: \(uuid.uuidString).")
        
        queue = Queue(bluejay: self)
    }
    
    deinit {
        queue.cancelAll()
        log("Deinit Bluejay with UUID: \(uuid.uuidString).")
    }
    
    public func start(
        connectionObserver observer: ConnectionObserver? = nil,
        listenRestorer restorer: ListenRestorer? = nil,
        enableBackgroundMode backgroundMode: Bool = false
        )
    {
        register(observer: queue)
        
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
        
        queue.add(scanOperation)
    }
    
    public func stopScanning() {
        cbCentralManager.stopScan()
        queue.stopScanning()
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
            
            queue.cancelAll(Error.unexpectedDisconnectError())
        }
        
        for observer in observers {
            observer.weakReference?.disconnected()
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
            queue.add(Connection(peripheral: cbPeripheral, manager: cbCentralManager, callback: completion))
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
            
            peripheralToDisconnect.cancelAllOperations()
            
            queue.add(Disconnection(peripheral: peripheralToDisconnect.cbPeripheral, manager: cbCentralManager, callback: { (result) in
                switch result {
                case .success(let peripheral):
                    log("Disconnected from \(String(describing: peripheral.name)).")
                    self.isDisconnecting = false
                    completion?(true)
                case .cancelled:
                    log("Disconnection from \(String(describing: peripheralToDisconnect.name)) cancelled.")
                    self.isDisconnecting = false
                    completion?(false)
                case .failure(let error):
                    log("Failed to disconnect with error: \(error.localizedDescription)")
                    self.isDisconnecting = false
                    completion?(false)
                }
            }))
        }
        else {
            log("Cannot disconnect: there is no connected peripheral.")
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
            completion(.failure(Error.notConnected()))
        }
    }
    
    /// Write to a specified characteristic.
    public func write<S: Sendable>(to characteristicIdentifier: CharacteristicIdentifier, value: S, completion: @escaping (WriteResult) -> Void) {
        if let peripheral = connectedPeripheral {
            peripheral.write(to: characteristicIdentifier, value: value, completion: completion)
        }
        else {
            completion(.failure(Error.notConnected()))
        }
    }
    
    /// Listen for notifications on a specified characteristic.
    public func listen<R: Receivable>(to characteristicIdentifier: CharacteristicIdentifier, completion: @escaping (ReadResult<R>) -> Void) {
        if let peripheral = connectedPeripheral {
            peripheral.listen(to: characteristicIdentifier, completion: completion)
        }
        else {
            completion(.failure(Error.notConnected()))
        }
    }
    
    /// End listening on a specified characteristic.
    public func endListen(to characteristicIdentifier: CharacteristicIdentifier, completion: ((WriteResult) -> Void)? = nil) {
        if let peripheral = connectedPeripheral {
            peripheral.endListen(to: characteristicIdentifier, error: nil, completion: completion)
        }
        else {
            completion?(.failure(Error.notConnected()))
        }
    }
    
    /// Restore a (beleived to be) active listening session, so if we start up in response to a notification, we can receivie it.
    public func restoreListen<R: Receivable>(to characteristicIdentifier: CharacteristicIdentifier, completion: @escaping (ReadResult<R>) -> Void) {
        if let peripheral = connectedPeripheral {
            peripheral.restoreListen(to: characteristicIdentifier, completion: completion)
        }
        else {
            completion(.failure(Error.notConnected()))
        }
    }
    
    /**
     Run a background task using a syncrounous interface to the Bluetooth device.
     
     - Warning
     Be careful not to access anything that is not thread safe from the background task callbacks.
     */
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
            completionOnMainThread(.failure(Error.notConnected()))
        }
    }
    
    // MARK: - Helpers
    
    /**
     Helper function to take an array of Sendables and combine their data together.
     
     - Parameter sendables: An array of Sendables whose Data should be appended in the order of the given array.
     
     - Returns: The resulting data of all the Sendables combined in the order of the passed in array.
     */
    public static func combine(sendables: [Sendable]) -> Data {
        let data = NSMutableData()
        
        for sendable in sendables {
            data.append(sendable.toBluetoothData())
        }
        
        return data as Data
    }
    
}

// MARK: - CBCentralManagerDelegate

extension Bluejay: CBCentralManagerDelegate {
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if #available(iOS 10.0, *) {
            log("CBCentralManager state updated: \(central.state.string())")
        } else {
            // Fallback on earlier versions
        }
        
        if central.state == .poweredOn {
            queue.start()
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
                observer.weakReference?.disconnected()
            }
        }
        
        UIApplication.shared.endBackgroundTask(backgroundTask)
    }
    
    private func attemptListenRestoration() {
        debugPrint("Starting listen restoration.")
        
        guard
            let listenCaches = UserDefaults.standard.dictionary(forKey: Constant.listenCaches),
            let cacheData = listenCaches[uuid.uuidString] as? [Data]
        else {
            debugPrint("No listens to restore.")
            return
        }
        
        for data in cacheData {
            let listenCache = (NSKeyedUnarchiver.unarchiveObject(with: data) as? (ListenCache.Coding))!
                .decoded as! ListenCache
            
            debugPrint("Listen cache to restore: \(listenCache)")
            
            let serviceIdentifier = ServiceIdentifier(uuid: listenCache.serviceUUID)
            let characteristicIdentifier = CharacteristicIdentifier(uuid: listenCache.characteristicUUID, service: serviceIdentifier)
            
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
        if !queue.isScanning() {
            for observer in observers {
                observer.weakReference?.connected(connectedPeripheral!)
            }
            
            shouldAutoReconnect = true
        }
        
        queue.process(event: .didConnectPeripheral(peripheral), error: nil)
        
        UIApplication.shared.endBackgroundTask(backgroundTask)
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Swift.Error?) {
        let backgroundTask =  UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
        
        let peripheralString = peripheral.name ?? peripheral.identifier.uuidString
        let errorString = error?.localizedDescription ?? ""
        
        debugPrint("Did disconnect from: \(peripheralString) with error: \(errorString)")
        
        if !queue.isEmpty() {
            queue.process(event: .didDisconnectPeripheral(peripheral), error: nil)
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
        // let peripheralString = advertisementData[CBAdvertisementDataLocalNameKey] ?? peripheral.identifier.uuidString
        // debugPrint("Did discover: \(peripheralString)")
        
        queue.process(event: .didDiscoverPeripheral(peripheral, advertisementData, RSSI), error: nil)
    }
    
}

func log(_ string: String) {
    debugPrint("[Bluejay-Debug] \(string)")
}
