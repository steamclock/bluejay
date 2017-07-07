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
 
 It also supports a few other niceties for simplifying usage, including automatic discovery of services and characteristics as they are used, as well as supporting a background task mode where the interaction with the device can be written as synchronous calls running on a background thread to avoid callback pyramids of death, or heavily chained promises.
 */
public class Bluejay: NSObject {
    
    // MARK: - Private Properties
    
    /// Internal reference to CoreBluetooth's CBCentralManager.
    fileprivate var cbCentralManager: CBCentralManager!
    
    /// The value for CBCentralManagerOptionRestoreIdentifierKey.
    fileprivate var restoreIdentifier: String?
    
    /// List of weak references to objects interested in receiving notifications on Bluetooth connection events and state changes.
    fileprivate var observers = [WeakConnectionObserver]()
    
    /// Reference to a peripheral that is still connecting. If this is nil, then the peripheral should either be disconnected or connected. This is used to help determine the state of the peripheral's connection.
    fileprivate var connectingPeripheral: Peripheral?
    
    /// Reference to a peripheral that is connected. If this is nil, then the peripheral should either be disconnected or still connecting. This is used to help determine the state of the peripheral's connection.
    fileprivate var connectedPeripheral: Peripheral?
    
    /// Allowing or disallowing reconnection attempts upon a disconnection. It should always be set to true, unless there is a manual and explicit disconnection request that is not caused by an error or an unexpected and programmatic disconnection.
    fileprivate var shouldAutoReconnect = true
    
    /// Reference to the background task used for supporting state restoration.
    fileprivate var startupBackgroundTask: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
    
    /// Reference to the peripheral identifier used for supporting state restoration.
    fileprivate var peripheralIdentifierToRestore: PeripheralIdentifier?
    
    /// Reference to the object capable of restoring listens during state restoration.
    fileprivate var listenRestorer: WeakListenRestorer?
    
    /// Determines whether state restoration is allowed.
    fileprivate var shouldRestoreState = false
    
    // MARK: - Internal Properties
    
    /// Contains the operations to execute in FIFO order.
    var queue: Queue!
    
    // MARK: - Public Properties
    
    /// Helps distinguish one Bluejay instance from another.
    public var uuid = UUID()
    
    /// Allows checking whether Bluetooth is powered on.
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
        // Cannot rely on the manager's state for isScanning as it is not usually updated immediately, and while that delay might be a more accurate representation of the current state, it is almost always more useful to evaluate whether Bluejay is running a scan request at the top of its queue.
        return queue.isScanning()
    }
    
    // MARK: - Initialization
    
    /**
     Initializing a Bluejay instance will not yet initialize the CoreBluetooth stack. An explicit call to start running a Bluejay instance after it is intialized is required because in cases where a state resotration is trying to restore a listen on a characteristic, a listen restorer must be available before the CoreBluetooth stack is re-initialized. This two-step startup allows you to insert and gaurantee the setup of your listen restorer in between the initialization of Bluejay and the initialization of the CoreBluetooth stack triggered via this call.
     */
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
        cancelEverything()
        
        log("Deinit Bluejay with UUID: \(uuid.uuidString).")
    }
    
    /**
     Starting Bluejay will initialize the CoreBluetooth stack. Initializing a Bluejay instance will not yet initialize the CoreBluetooth stack. An explicit call to start running a Bluejay instance after it is intialized is required because in cases where a state resotration is trying to restore a listen on a characteristic, a listen restorer must be available before the CoreBluetooth stack is re-initialized. This two-step startup allows you to insert and gaurantee the setup of your listen restorer in between the initialization of Bluejay and the initialization of the CoreBluetooth stack triggered via this call.
     
     - Parameters:
        - observer: An object interested in observing Bluetooth connection events and state changes. You can register more observers using the `register` function.
        - restoreMode: Determines whether Bluejay will opt-in to state restoration, and if so, can optionally provide a listen restorer as well for restoring listens.
    */
    public func start(
        connectionObserver observer: ConnectionObserver? = nil,
        backgroundRestore restoreMode: BackgroundRestoreMode = .disable
        )
    {
        if cbCentralManager != nil {
            log("Error: The Bluejay instance with UUID: \(uuid.uuidString) has already started.")
            return
        }
        
        register(observer: queue)
        
        if let observer = observer {
            register(observer: observer)
        }
        
        var options: [String : Any] = [CBCentralManagerOptionShowPowerAlertKey : false]
        
        switch restoreMode {
        case .disable:
            break
        case .enable(let restoreIdentifier):
            checkBackgroundSupportForBluetooth()
            options[CBCentralManagerOptionRestoreIdentifierKey] = restoreIdentifier
        case .enableWithListenRestorer(let restoreIdentifier, let restorer):
            checkBackgroundSupportForBluetooth()
            options[CBCentralManagerOptionRestoreIdentifierKey] = restoreIdentifier
            listenRestorer = WeakListenRestorer(weakReference: restorer)
        }
        
        cbCentralManager = CBCentralManager(
            delegate: self,
            queue: DispatchQueue.main,
            options: options
        )
    }
    
    private func checkBackgroundSupportForBluetooth() {
        var isSupported = false
        
        if let backgroundModes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] {
            isSupported = backgroundModes.contains("bluetooth-central")
        }

        if !isSupported {
            log("Warning: It appears your app has not enabled background support for Bluetooth properly. Please make sure the capability, Background Modes, is turned on, and the setting, Uses Bluetooth LE accessories, is checked in your Xcode project.")
        }
    }
    
    /**
     This will cancel the current and all pending operations in the Bluejay queue, as well as stop any ongoing scan, and disconnect any connected peripheral.
     
     - Parameter error: If nil, all tasks in the queue will be cancelled without any errors. If an error is provided, all tasks in the queue will be failed with the supplied error.
     */
    public func cancelEverything(_ error: NSError? = nil) {
        shouldAutoReconnect = false

        queue.cancelAll(error)
        
        if isConnected {
            cbCentralManager.cancelPeripheralConnection(connectedPeripheral!.cbPeripheral)
        }
        
        connectingPeripheral = nil
        connectedPeripheral = nil
    }
    
    // MARK: - Events Registration
    
    /**
     Register for notifications on Bluetooth connection events and state changes. Unregistering is not required, Bluejay will unregister for you if the observer is no longer in memory.
     
     - Parameter observer:
     */
    public func register(observer: ConnectionObserver) {
        observers = observers.filter { $0.weakReference != nil && $0.weakReference !== observer }
        observers.append(WeakConnectionObserver(weakReference: observer))
        
        if cbCentralManager != nil {
            observer.bluetoothAvailable(cbCentralManager.state == .poweredOn)
        }
        
        if let connectedPeripheral = connectedPeripheral {
            observer.connected(to: connectedPeripheral)
        }
    }
    
    /**
     Unregister for notifications on Bluetooth connection events and state changes. Unregistering is not required, Bluejay will unregister for you if the observer is no longer in memory.
     
     - Parameter observer:
     */
    public func unregister(observer: ConnectionObserver) {
        observers = observers.filter { $0.weakReference != nil && $0.weakReference !== observer }
    }
    
    // MARK: - Scanning
    
    /**
     Scan for the peripheral(s) specified.
     
     - Parameters:
        - duration: Stops the scan when the duration in seconds is reached. Defaults to zero (indefinite).
        - allowDuplicates: Determines whether a previously scanned peripheral is allowed to be discovered again.
        - serviceIdentifiers: Specifies what visible services the peripherals must have in order to be discovered.
        - discovery: Called whenever a specified peripheral has been discovered.
        - expired: Called whenever a previously discovered peripheral has not been seen again for a while, and Bluejay is predicting that it may no longer be in range. (Only for a scan with allowDuplicates enabled)
        - stopped: Called when the scan is finished and provides an error if there is any.
     */
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
    
    /// Stops an ongoing scan if there is one, otherwise it does nothing.
    public func stopScanning() {
        queue.stopScanning()
    }
    
    // MARK: - Connection
    
    /**
     Attempt to connect directly to a known peripheral. The call will fail if Bluetooth is not available, or if Bluejay is already connected. Making a connection request while Bluejay is scanning will also cause Bluejay to stop the current scan for you behind the scene prior to fulfilling your connection request.
     
     - Parameters:
        - peripheralIdentifier: The peripheral to connect to.
        - completion: Called when the connection request has fully finished and indicates whether it was successful, cancelled, or failed.
    */
    public func connect(_ peripheralIdentifier: PeripheralIdentifier, completion: @escaping (ConnectionResult) -> Void) {
        // Block a connect request when restoring, restore should result in the peripheral being automatically connected.
        if (shouldRestoreState) {
            // Cache requested connect, in case restore messes up unexpectedly.
            peripheralIdentifierToRestore = peripheralIdentifier
            return
        }
        
        if let cbPeripheral = cbCentralManager.retrievePeripherals(withIdentifiers: [peripheralIdentifier.uuid]).first {
            queue.add(Connection(peripheral: cbPeripheral, manager: cbCentralManager, callback: completion))
        }
        else {
            completion(.failure(Error.unexpectedPeripheral(peripheralIdentifier)))
        }
    }
    
    /**
     Disconnect the currently connected peripheral. Providing a completion block is not necessary, but useful in most cases.
     
     - parameter completion: Called when the disconnection request has fully finished and indicates whether it was successful, cancelled, or failed.
    */
    public func disconnect(completion: ((DisconnectionResult) -> Void)? = nil) {
        if isDisconnecting {
            completion?(.failure(Error.multipleDisconnect()))
            return
        }
        
        if let peripheralToDisconnect = connectedPeripheral {
            isDisconnecting = true
            shouldAutoReconnect = false
            
            queue.cancelAll()
            
            queue.add(Disconnection(
                peripheral: peripheralToDisconnect.cbPeripheral,
                manager: cbCentralManager,
                callback: { (result) in
                    switch result {
                    case .success(let peripheral):
                        self.isDisconnecting = false
                        completion?(.success(peripheral))
                    case .cancelled:
                        self.isDisconnecting = false
                        completion?(.cancelled)
                    case .failure(let error):
                        self.isDisconnecting = false
                        completion?(.failure(error))
                    }
            }))
        }
        else {
            log("Cannot disconnect: there is no connected peripheral.")
            isDisconnecting = false
            completion?(.failure(Error.notConnected()))
        }
    }
    
    // MARK: - Actions
    
    /**
     Read from the specified characteristic.
     
     - Parameters:
        - characteristicIdentifier: The characteristic to read from.
        - completion: Called with the result of the attempt to read from the specified characteristic.
    */
    public func read<R: Receivable>(from characteristicIdentifier: CharacteristicIdentifier, completion: @escaping (ReadResult<R>) -> Void) {
        if let peripheral = connectedPeripheral {
            peripheral.read(from: characteristicIdentifier, completion: completion)
        }
        else {
            completion(.failure(Error.notConnected()))
        }
    }
    
    /**
     Write to the specified characteristic.
     
     - Parameters:
        - characteristicIdentifier: The characteristic to write to.
        - completion: Called with the result of the attempt to write to the specified characteristic.
    */
    public func write<S: Sendable>(to characteristicIdentifier: CharacteristicIdentifier, value: S, completion: @escaping (WriteResult) -> Void) {
        if let peripheral = connectedPeripheral {
            peripheral.write(to: characteristicIdentifier, value: value, completion: completion)
        }
        else {
            completion(.failure(Error.notConnected()))
        }
    }
    
    /**
     Listen for notifications on the specified characteristic.
     
     - Parameters:
        - characteristicIdentifier: The characteristic to listen to.
        - completion: Called with the result of the attempt to listen for notifications on the specified characteristic.
     */
    public func listen<R: Receivable>(to characteristicIdentifier: CharacteristicIdentifier, completion: @escaping (ReadResult<R>) -> Void) {
        if let peripheral = connectedPeripheral {
            peripheral.listen(to: characteristicIdentifier, completion: completion)
        }
        else {
            completion(.failure(Error.notConnected()))
        }
    }
    
    /**
     End listening on the specified characteristic.
     
     - Parameters:
        - characteristicIdentifier: The characteristic to stop listening to.
        - completion: Called with the result of the attempt to stop listening to the specified characteristic.
    */
    public func endListen(to characteristicIdentifier: CharacteristicIdentifier, completion: ((WriteResult) -> Void)? = nil) {
        if let peripheral = connectedPeripheral {
            peripheral.endListen(to: characteristicIdentifier, error: nil, completion: completion)
        }
        else {
            completion?(.failure(Error.notConnected()))
        }
    }
    
    /**
     Restore a (believed to be) active listening session, so if we start up in response to a notification, we can receive it.
     
     - Parameters:
        - characteristicIdentifier: The characteristic that needs the restoration.
        - completion: Called with the result of the attempt to restore the listen on the specified characteristic.
    */
    public func restoreListen<R: Receivable>(to characteristicIdentifier: CharacteristicIdentifier, completion: @escaping (ReadResult<R>) -> Void) {
        if let peripheral = connectedPeripheral {
            peripheral.restoreListen(to: characteristicIdentifier, completion: completion)
        }
        else {
            completion(.failure(Error.notConnected()))
        }
    }
    
    // MARK: - Background Task
    
    /**
     One of the three ways to run a background task using a synchronous interface to the Bluetooth peripheral. This is the simplest one as the background task will not return any typed values back to the completion block on finishing the background task, except for thrown errors, and it also doesn't provide an input for an object that might need thread safe access.
     
     - Warning: Be careful not to access anything that is not thread safe inside background task.
     
     - Parameters:
        - backgroundTask: A closure with the jobs to be executed in the background.
        - completionOnMainThread: A closure called on the main thread when the background task has either completed or failed.
     */
    public func run(
        backgroundTask: @escaping (SynchronizedPeripheral) throws -> Void,
        completionOnMainThread: @escaping (RunResult<Void>) -> Void)
    {
        if let peripheral = connectedPeripheral {
            DispatchQueue.global().async {
                do {
                    try backgroundTask(SynchronizedPeripheral(parent: peripheral))
                    
                    DispatchQueue.main.async {
                        completionOnMainThread(.success())
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
    
    /**
     One of the three ways to run a background task using a synchronous interface to the Bluetooth peripheral. This one allows the background task to potentially return a typed value back to the completion block on finishing the background task successfully.
     
     - Warning: Be careful not to access anything that is not thread safe inside background task.
     
     - Parameters:
        - backgroundTask: A closure with the jobs to be executed in the background.
        - completionOnMainThread: A closure called on the main thread when the background task has either completed or failed.
     */
    public func run<Result>(
        backgroundTask: @escaping (SynchronizedPeripheral) throws -> Result,
        completionOnMainThread: @escaping (RunResult<Result>) -> Void)
    {
        if let peripheral = connectedPeripheral {
            DispatchQueue.global().async {
                do {
                    let result = try backgroundTask(SynchronizedPeripheral(parent: peripheral))
                    
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
    
    /**
     One of the three ways to run a background task using a synchronous interface to the Bluetooth peripheral. This one allows the background task to potentially return a typed value back to the completion block on finishing the background task successfully, as well as supplying an object for thread safe access inside the background task.
     
     - Warning: Be careful not to access anything that is not thread safe inside background task.
     
     - Parameters:
        - userData: Any object you wish to have thread safe access inside background task.
        - backgroundTask: A closure with the jobs to be executed in the background.
        - completionOnMainThread: A closure called on the main thread when the background task has either completed or failed.
     */
    public func run<UserData, Result>(
        userData: UserData,
        backgroundTask: @escaping (SynchronizedPeripheral, UserData) throws -> Result,
        completionOnMainThread: @escaping (RunResult<Result>) -> Void)
    {
        if let peripheral = connectedPeripheral {
            DispatchQueue.global().async {
                do {
                    let result = try backgroundTask(SynchronizedPeripheral(parent: peripheral), userData)
                    
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
     A helper function to take an array of Sendables and combine their data together.
     
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
        let backgroundTask = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)

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
        
        if central.state == .poweredOff {
            cancelEverything(Error.bluetoothUnavailable())
        }
        
        for observer in observers {
            observer.weakReference?.bluetoothAvailable(central.state == .poweredOn)
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
        
        for observer in observers {
            observer.weakReference?.connected(to: connectedPeripheral!)
        }
        
        shouldAutoReconnect = true
        
        queue.process(event: .didConnectPeripheral(peripheral), error: nil)
        
        UIApplication.shared.endBackgroundTask(backgroundTask)
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Swift.Error?) {
        let backgroundTask =  UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
        
        let peripheralString = peripheral.name ?? peripheral.identifier.uuidString
        let errorString = error?.localizedDescription
        
        if let errorMessage = errorString {
            log("Did disconnect from \(peripheralString) with error: \(errorMessage)")
        }
        else {
            log("Did disconnect from \(peripheralString) without errors.")
        }
        
        for observer in observers {
            observer.weakReference?.disconnected(from: Peripheral(bluejay: self, cbPeripheral: peripheral))
        }
        
        if !queue.isEmpty() {
            // If Bluejay is currently disconnecting, the queue needs to process this disconnection event. Otherwise, this is an unexpected disconnection.
            if isDisconnecting {
                queue.process(event: .didDisconnectPeripheral(peripheral), error: error as NSError?)
            }
            else {
                queue.cancelAll(Error.notConnected())
            }
        }
        
        connectingPeripheral = nil
        connectedPeripheral = nil
        
        log("Should auto-reconnect: \(shouldAutoReconnect)")
        
        if shouldAutoReconnect {
            log("Issuing reconnect to: \(peripheral.name ?? peripheral.identifier.uuidString)")
            connect(PeripheralIdentifier(uuid: peripheral.identifier), completion: {_ in })
        }
        
        UIApplication.shared.endBackgroundTask(backgroundTask)
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Swift.Error?) {
        // Use the same clean up logic provided in the did disconnect callback.
        centralManager(central, didDisconnectPeripheral: peripheral, error: error)
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // let peripheralString = advertisementData[CBAdvertisementDataLocalNameKey] ?? peripheral.identifier.uuidString
        // debugPrint("Did discover: \(peripheralString)")
        
        queue.process(event: .didDiscoverPeripheral(peripheral, advertisementData, RSSI), error: nil)
    }
    
}

extension Bluejay: QueueObserver {
    
    func willConnect(to peripheral: CBPeripheral) {
        connectingPeripheral = Peripheral(bluejay: self, cbPeripheral: peripheral)
    }
    
}

func log(_ string: String) {
    debugPrint("[Bluejay-Debug] \(string)")
}
