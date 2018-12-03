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
public class Bluejay: NSObject { //swiftlint:disable:this type_body_length

    // MARK: - Private Properties

    /// Internal reference to CoreBluetooth's CBCentralManager.
    private var cbCentralManager: CBCentralManager!

    /// List of weak references to objects interested in receiving notifications on Bluetooth connection events and state changes.
    private var observers = [WeakConnectionObserver]()

    private weak var disconnectHandler: DisconnectHandler?

    private var connectingPeripheralAtRestoration: Peripheral?

    /// Reference to a peripheral that is still connecting. If this is nil, then the peripheral should either be disconnected or connected. This is used to help determine the state of the peripheral's connection.
    private var connectingPeripheral: Peripheral?

    /// Reference to a peripheral that is connected. If this is nil, then the peripheral should either be disconnected or still connecting. This is used to help determine the state of the peripheral's connection.
    private var connectedPeripheral: Peripheral?

    /// Reference to the background task used for supporting state restoration.
    private var startupBackgroundTask: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid

    /// Determines whether state restoration is allowed.
    private var shouldRestoreState = false

    /// True when background task is running, and helps prevent calling regular read/write/listen.
    private var isRunningBackgroundTask = false

    /// Allows caching and defering disconnect notifications and final clean ups when there is a disconnection while running a Bluejay background task.
    private var disconnectCleanUp: (() -> Void)?

    /// Cache for an explicit disconnect callback if provided.
    private var disconnectCallback: ((DisconnectionResult) -> Void)?

    /// Cache for a connection callback and used if the connection fails to complete.
    private var connectingCallback: ((ConnectionResult) -> Void)?

    // MARK: - Internal Properties

    /// Contains the operations to execute in FIFO order.
    var queue: Queue!

    /// The value for CBCentralManagerOptionRestoreIdentifierKey.
    var restoreIdentifier: RestoreIdentifier?

    /// The delegate responsible for handling background restoration results.
    weak var backgroundRestorer: BackgroundRestorer?

    /// Reference to the object capable of restoring listens during state restoration.
    weak var listenRestorer: ListenRestorer?

    /// The previous connection timeout used.
    var previousConnectionTimeout: Timeout?

    // MARK: - Public Properties

    /// Helps distinguish one Bluejay instance from another.
    public let uuid = UUID()

    /// Allows checking whether Bluetooth is powered on. Also returns false if Bluejay is not started yet.
    public var isBluetoothAvailable: Bool {
        if cbCentralManager == nil {
            return false
        } else {
            return cbCentralManager.state == .poweredOn
        }
    }

    /// Allows checking for if CoreBluetooth state is transitional (update is imminent)
    /// please re-evaluate the bluetooth state again as it may change momentarily after it has returned true 
    public var isBluetoothStateUpdateImminent: Bool {
        return cbCentralManager.state == .unknown ||
            cbCentralManager.state == .resetting
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
    private(set) public var isDisconnecting: Bool = false

    /// Allowing checking whether Bluejay will automatic reconnect after an unexpected disconnection. Default is true, and Bluejay will also always set this to true on a successful connection to a peripheral. Conversely, Bluejay will always set this to false after an explicit disconnection request.
    private(set) public var shouldAutoReconnect = true

    /// Allows checking whether Bluejay is currently scanning.
    public var isScanning: Bool {
        // Cannot rely on the manager's state for isScanning as it is not usually updated immediately, and while that delay might be a more accurate representation of the current state, it is almost always more useful to evaluate whether Bluejay is running a scan request at the top of its queue.
        return queue.isScanning
    }

    /// Allows checking whether Bluejay has started and is available for use.
    public var hasStarted: Bool {
        return cbCentralManager != nil
    }

    /// Warning options to use for each new connection if the options are not specified at the creation of those connections.
    private(set) public var defaultWarningOptions = WarningOptions.default

    // MARK: - Initialization

    /**
     Initializing a Bluejay instance will not yet initialize the CoreBluetooth stack. An explicit `start` call after Bluejay is intialized will then initialize the CoreBluetooth stack and is required because in cases where a state resotration is trying to restore a listen on a characteristic, a listen restorer must be available before the CoreBluetooth stack is re-initialized. This two-step startup allows you to prepare and gaurantee the setup of your listen restorer in between the initialization of Bluejay and the initialization of the CoreBluetooth stack.
     */
    public override init() {
        super.init()

        shouldRestoreState = UIApplication.shared.applicationState == .background

        if shouldRestoreState {
            log("Begin startup background task for restoring CoreBluetooth.")
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
     Starting Bluejay will initialize the CoreBluetooth stack. Simply initializing a Bluejay instance without calling this function will not initialize the CoreBluetooth stack. An explicit start call is required because in cases where a state resotration is trying to restore a listen on a characteristic, a listen restorer must be available before the CoreBluetooth stack is re-initialized. This two-step startup (init then start) allows you to prepare and gaurantee the setup of your listen restorer in between the initialization of Bluejay and the initialization of the CoreBluetooth stack.
     
     - Parameters:
        - mode: CoreBluetooth initialization modes and options.
        - observer: A delegate interested in observing Bluetooth connection events and state changes.
        - handler: A single delegate with the final say on what to do at the end of a disconnection and control auto-reconnect behaviour
    */
    public func start(mode: StartMode = .new(StartOptions.default), connectionObserver observer: ConnectionObserver? = nil, disconnectHandler handler: DisconnectHandler? = nil) {
        /**
         If a call to start is made while the app is still in the background (can happen if Bluejay is instantiated and started in the initialization of UIApplicationDelegate for example), Bluejay will mistake its unexpectedly early instantiation as an instantiation from background restoration.
         
         Therefore, an explicit call to start should assume that Bluejay is not initialized from background restoration, as the code flow for background restoration should not involve a call to start.
         */
        shouldRestoreState = false
        if startupBackgroundTask != UIBackgroundTaskInvalid {
            debugPrint("Cancelling startup background task.")
            UIApplication.shared.endBackgroundTask(startupBackgroundTask)
        }

        if cbCentralManager != nil {
            log("Error: The Bluejay instance with UUID: \(uuid.uuidString) has already started.")
            return
        }

        switch mode {
        case .new(let startOptions):
            register(observer: queue)

            if let observer = observer {
                register(observer: observer)
            }

            if let handler = handler {
                registerDisconnectHandler(handler: handler)
            }

            var managerOptions: [String: Any] = [CBCentralManagerOptionShowPowerAlertKey: startOptions.enableBluetoothAlert]

            switch startOptions.backgroundRestore {
            case .disable:
                break
            case .enable(let restoreID, let bgRestorer):
                checkBackgroundSupportForBluetooth()
                restoreIdentifier = restoreID
                backgroundRestorer = bgRestorer
                managerOptions[CBCentralManagerOptionRestoreIdentifierKey] = restoreIdentifier
            case .enableWithListenRestorer(let restoreID, let bgRestorer, let liRestorer):
                checkBackgroundSupportForBluetooth()
                restoreIdentifier = restoreID
                backgroundRestorer = bgRestorer
                listenRestorer = liRestorer
                managerOptions[CBCentralManagerOptionRestoreIdentifierKey] = restoreIdentifier
            }

            cbCentralManager = CBCentralManager(
                delegate: self,
                queue: .main,
                options: managerOptions
            )
        case .use(let manager, let peripheral):
            cbCentralManager = manager

            if let peripheral = peripheral {
                connectedPeripheral = Peripheral(bluejay: self, cbPeripheral: peripheral)
                peripheral.delegate = connectedPeripheral
            }
        }
    }

    /**
     Stops all operations and clears all states in Bluejay before returning a Core Bluetooth state that can then be used by another library or code outside of Bluejay.
     
     - Returns: Returns a CBCentralManager and possibly a CBPeripheral as well if there was one connected at the time of this call.
     - Warning: Will crash if Bluejay has not been instantiated properly or if Bluejay is still connecting.
    */
    public func stopAndExtractBluetoothState() -> (manager: CBCentralManager, peripheral: CBPeripheral?) {
        precondition(cbCentralManager != nil)
        precondition(!isConnecting)

        defer {
            connectedPeripheral?.cbPeripheral.delegate = nil
            connectedPeripheral = nil

            cbCentralManager.delegate = nil
            cbCentralManager = nil
        }

        cancelEverything(error: BluejayError.stopped, shouldDisconnect: false)

        observers.removeAll()
        disconnectHandler = nil

        return (manager: cbCentralManager, peripheral: connectedPeripheral?.cbPeripheral)
    }

    /// Check to see whether the "Uses Bluetooth LE accessories" capability is turned on in the residing Xcode project.
    private func checkBackgroundSupportForBluetooth() {
        var isSupported = false

        if let backgroundModes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] {
            isSupported = backgroundModes.contains("bluetooth-central")
        }

        if !isSupported {
            log("""
                Warning: It appears your app has not enabled background support for Bluetooth properly. \
                Please make sure the capability, "Background Modes", is turned on, and the setting, "Uses Bluetooth LE accessories", \
                is checked in your Xcode project.
                """)
        }
    }

    // MARK: - Cancellation

    /**
     This will cancel the current and all pending operations in the Bluejay queue. It will also disconnect by default after the queue is emptied, but you can cancel everything without disconnecting.
     
     - Parameters:
       - error: Defaults to a generic `cancelled` error. Pass in a specific error if you want to deliver a specific error to all of your running and queued tasks.
       - shouldDisconnect: Defaults to true, will not disconnect if set to false, but only matters if Bluejay is actually connected.
     */
    public func cancelEverything(error: Error = BluejayError.cancelled, shouldDisconnect: Bool = true) {
        log("Cancel everything called with error: \(error.localizedDescription), shouldDisconnect: \(shouldDisconnect)")

        if isConnecting {
            log("Cancel everything called while still connecting...")

            isDisconnecting = true
            shouldAutoReconnect = false

            log("Should auto-reconnect: \(shouldAutoReconnect)")
        }

        queue.cancelAll(error: error)

        if isConnected && shouldDisconnect {
            log("Cancel everything will now disconnect a connected peripheral...")

            isDisconnecting = true
            shouldAutoReconnect = false

            log("Should auto-reconnect: \(shouldAutoReconnect)")

            cbCentralManager.cancelPeripheralConnection(connectedPeripheral!.cbPeripheral)
        }
    }

    /**
     This will remove any cached listens associated with the receiving Bluejay's restore identifier. Call this if you want to stop Bluejay from attempting to restore any listens when state restoration occurs.
     
     - Note: For handling a single specific characteristic, use `endListen`. If that succeeds, it will not only stop the listening on that characteristic, it will also remove that listen from the cache for state restoration if listen restoration is enabled, and if that listen was indeed cached for restoration.
     */
    public func clearListenCaches() {
        guard
            let restoreIdentifier = restoreIdentifier,
            let listenCaches = UserDefaults.standard.dictionary(forKey: Constant.listenCaches)
        else {
            log("Unable to clear listen caches: nothing to clear.")
            return
        }

        var newListenCaches = listenCaches
        newListenCaches.removeValue(forKey: restoreIdentifier)

        UserDefaults.standard.set(newListenCaches, forKey: Constant.listenCaches)
        UserDefaults.standard.synchronize()
    }

    // MARK: - Events Registration

    /**
     Register for notifications on Bluetooth connection events and state changes. Unregistering is not required, Bluejay will unregister for you if the observer is no longer in memory.
     
     - Parameter observer: object interested in receiving Bluejay's Bluetooth connection related events.
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
     
     - Parameter observer: object no longer interested in receiving Bleujay's connection related events.
     */
    public func unregister(observer: ConnectionObserver) {
        observers = observers.filter { $0.weakReference != nil && $0.weakReference !== observer }
    }

    /**
     Register a single disconnection handler for giving it a final say on what to do at the end of a disconnection, as well as evaluate and control Bluejay's auto-reconnect behaviour.
     
     - Parameter handler: object interested in becoming Bluejay's optional but most featureful disconnection handler.
    */
    public func registerDisconnectHandler(handler: DisconnectHandler) {
        disconnectHandler = handler
    }

    /**
     Remove any registered disconnection handler.
    */
    public func unregisterDisconnectHandler() {
        disconnectHandler = nil
    }

    // MARK: - Scanning

    /**
     Scan for the peripheral(s) specified.

     - Warning: Setting `serviceIdentifiers` to `nil` will result in picking up all available Bluetooth peripherals in the vicinity, **but is not recommended by Apple**. It may cause battery and cpu issues on prolonged scanning, and **it also doesn't work in the background**. If you need to scan for all Bluetooth devices, we recommend making use of the `duration` parameter to stop the scan after 5 ~ 10 seconds to avoid scanning indefinitely and overloading the hardware.
     
     - Parameters:
        - duration: Stops the scan when the duration in seconds is reached. Defaults to zero (indefinite).
        - allowDuplicates: Determines whether a previously scanned peripheral is allowed to be discovered again.
        - throttleRSSIDelta: Throttles discoveries by ignoring insignificant changes to RSSI.
        - serviceIdentifiers: Specifies what visible services the peripherals must have in order to be discovered.
        - discovery: Called whenever a specified peripheral has been discovered.
        - expired: Called whenever a previously discovered peripheral has not been seen again for a while, and Bluejay is predicting that it may no longer be in range. (Only for a scan with allowDuplicates enabled)
        - stopped: Called when the scan is finished and provides an error if there is any.
     */
    public func scan(
        duration: TimeInterval = 0,
        allowDuplicates: Bool = false,
        throttleRSSIDelta: Int = 5,
        serviceIdentifiers: [ServiceIdentifier]?,
        discovery: @escaping (ScanDiscovery, [ScanDiscovery]) -> ScanAction,
        expired: ((ScanDiscovery, [ScanDiscovery]) -> ScanAction)? = nil,
        stopped: @escaping ([ScanDiscovery], Error?) -> Void
        ) {
        if isRunningBackgroundTask {
            // Terminate the app if this is called from the same thread as the running background task.
            if #available(iOS 10.0, *) {
                Dispatch.dispatchPrecondition(condition: .notOnQueue(.global()))
            } else {
                // Fallback on earlier versions
            }
            log("Warning: You cannot start a scan while a background task is still running.")
            return
        }

        let scanOperation = Scan(
            duration: duration,
            allowDuplicates: allowDuplicates,
            throttleRSSIDelta: throttleRSSIDelta,
            serviceIdentifiers: serviceIdentifiers,
            discovery: discovery,
            expired: expired,
            stopped: stopped,
            manager: cbCentralManager
        )

        queue.add(scanOperation)
    }

    /// Stops current or queued scan.
    public func stopScanning() {
        if isRunningBackgroundTask {
            // Terminate the app if this is called from the same thread as the running background task.
            if #available(iOS 10.0, *) {
                Dispatch.dispatchPrecondition(condition: .notOnQueue(.global()))
            } else {
                // Fallback on earlier versions
            }
            log("Warning: You cannot stop a scan while a background task is still running.")
            return
        }

        queue.stopScanning()
    }

    // MARK: - Connection

    /**
     Attempt to connect directly to a known peripheral. The call will fail if Bluetooth is not available, or if Bluejay is already connected. Making a connection request while Bluejay is scanning will also cause Bluejay to stop the current scan for you behind the scene prior to fulfilling your connection request.
     
     - Parameters:
        - peripheralIdentifier: The peripheral to connect to.
        - timeout: Specify how long the connection time out should be.
        - warningOptions: Optional connection warning options, if not specified, Bluejay's default will be used.
        - completion: Called when the connection request has ended.
    */
    public func connect(
        _ peripheralIdentifier: PeripheralIdentifier,
        timeout: Timeout,
        warningOptions: WarningOptions? = nil,
        completion: @escaping (ConnectionResult) -> Void) {
        previousConnectionTimeout = timeout

        if isRunningBackgroundTask {
            // Terminate the app if this is called from the same thread as the running background task.
            if #available(iOS 10.0, *) {
                Dispatch.dispatchPrecondition(condition: .notOnQueue(.global()))
            } else {
                // Fallback on earlier versions
            }
            completion(.failure(BluejayError.backgroundTaskRunning))
            return
        }

        if let cbPeripheral = cbCentralManager.retrievePeripherals(withIdentifiers: [peripheralIdentifier.uuid]).first {
            connectingCallback = completion

            queue.add(Connection(
                peripheral: cbPeripheral,
                manager: cbCentralManager,
                timeout: timeout,
                warningOptions: warningOptions ?? defaultWarningOptions,
                callback: completion)
            )
        } else {
            completion(.failure(BluejayError.unexpectedPeripheral(peripheralIdentifier)))
        }
    }

    /**
     Disconnect a connected peripheral or cancel a connecting peripheral.
     
     - Attention: If you are going to use the completion block, be careful on how you orchestrate and organize multiple disconnection callbacks if you are also using a `DisconnectHandler`.
     
     - Parameters:
        - immediate: If true, the disconnect will not be enqueued and will cancel everything in the queue immediately then disconnect. If false, the disconnect will wait until everything in the queue is finished.
        - completion: Called when the disconnect request is fully completed.
    */
    public func disconnect(immediate: Bool = false, completion: ((DisconnectionResult) -> Void)? = nil) {
        if isRunningBackgroundTask {
            // Terminate the app if this is called from the same thread as the running background task.
            if #available(iOS 10.0, *) {
                Dispatch.dispatchPrecondition(condition: .notOnQueue(.global()))
            } else {
                // Fallback on earlier versions
            }
            log("Warning: You've tried to disconnect while a background task is still running. The disconnect call will either do nothing, or fail if a completion block is provided.")
            completion?(.failure(BluejayError.backgroundTaskRunning))
            return
        }

        if isDisconnecting || (immediate == false && queue.isDisconnectionQueued) {
            completion?(.failure(BluejayError.multipleDisconnectNotSupported))
            return
        }

        if isConnecting || isConnected {
            log("Explicit disconnect called.")

            disconnectCallback = completion
            shouldAutoReconnect = false

            if immediate {
                isDisconnecting = true
                cancelEverything(error: BluejayError.explicitDisconnect)
            } else {
                if let peripheral = connectingPeripheral?.cbPeripheral ?? connectedPeripheral?.cbPeripheral {
                    queue.add(Disconnection(peripheral: peripheral, manager: cbCentralManager, callback: completion))
                } else {
                    log("Cannot disconnect: there is no connected nor connecting peripheral.")
                    completion?(.failure(BluejayError.notConnected))
                }
            }
        } else {
            log("Cannot disconnect: there is no connected nor connecting peripheral.")
            isDisconnecting = false
            completion?(.failure(BluejayError.notConnected))
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
        if isRunningBackgroundTask {
            // Terminate the app if this is called from the same thread as the running background task.
            if #available(iOS 10.0, *) {
                Dispatch.dispatchPrecondition(condition: .notOnQueue(.global()))
            } else {
                // Fallback on earlier versions
            }
            completion(.failure(BluejayError.backgroundTaskRunning))
            return
        }

        if let peripheral = connectedPeripheral {
            peripheral.read(from: characteristicIdentifier, completion: completion)
        } else {
            completion(.failure(BluejayError.notConnected))
        }
    }

    /**
     Write to the specified characteristic.
     
     - Parameters:
        - characteristicIdentifier: The characteristic to write to.
        - type: Write type.
        - completion: Called with the result of the attempt to write to the specified characteristic.
    */
    public func write<S: Sendable>(to characteristicIdentifier: CharacteristicIdentifier, value: S, type: CBCharacteristicWriteType = .withResponse, completion: @escaping (WriteResult) -> Void) {
        if isRunningBackgroundTask {
            // Terminate the app if this is called from the same thread as the running background task.
            if #available(iOS 10.0, *) {
                Dispatch.dispatchPrecondition(condition: .notOnQueue(.global()))
            } else {
                // Fallback on earlier versions
            }
            completion(.failure(BluejayError.backgroundTaskRunning))
            return
        }

        if let peripheral = connectedPeripheral {
            peripheral.write(to: characteristicIdentifier, value: value, type: type, completion: completion)
        } else {
            completion(.failure(BluejayError.notConnected))
        }
    }

    /**
     Listen for notifications on the specified characteristic.
     
     - Parameters:
        - characteristicIdentifier: The characteristic to listen to.
        - completion: Called with the result of the attempt to listen for notifications on the specified characteristic.
     */
    public func listen<R: Receivable>(to characteristicIdentifier: CharacteristicIdentifier, completion: @escaping (ReadResult<R>) -> Void) {
        if isRunningBackgroundTask {
            // Terminate the app if this is called from the same thread as the running background task.
            if #available(iOS 10.0, *) {
                Dispatch.dispatchPrecondition(condition: .notOnQueue(.global()))
            } else {
                // Fallback on earlier versions
            }
            completion(.failure(BluejayError.backgroundTaskRunning))
            return
        }

        if let peripheral = connectedPeripheral {
            peripheral.listen(to: characteristicIdentifier, completion: completion)
        } else {
            completion(.failure(BluejayError.notConnected))
        }
    }

    /**
     End listening on the specified characteristic.
     
     - Parameters:
        - characteristicIdentifier: The characteristic to stop listening to.
        - completion: Called with the result of the attempt to stop listening to the specified characteristic.
    */
    public func endListen(to characteristicIdentifier: CharacteristicIdentifier, completion: ((WriteResult) -> Void)? = nil) {
        if isRunningBackgroundTask {
            // Terminate the app if this is called from the same thread as the running background task.
            if #available(iOS 10.0, *) {
                Dispatch.dispatchPrecondition(condition: .notOnQueue(.global()))
            } else {
                // Fallback on earlier versions
            }
            log("Warning: You've tried to end a listen while a background task is still running. The endListen call will either do nothing, or fail if a completion block is provided.")
            completion?(.failure(BluejayError.backgroundTaskRunning))
            return
        }

        if let peripheral = connectedPeripheral {
            peripheral.endListen(to: characteristicIdentifier, error: nil, completion: completion)
        } else {
            completion?(.failure(BluejayError.notConnected))
        }
    }

    /**
     Restore a (believed to be) active listening session, so if we start up in response to a notification, we can receive it.
     
     - Parameters:
        - characteristicIdentifier: The characteristic that needs the restoration.
        - completion: Called with the result of the attempt to restore the listen on the specified characteristic.
    */
    public func restoreListen<R: Receivable>(to characteristicIdentifier: CharacteristicIdentifier, completion: @escaping (ReadResult<R>) -> Void) {
        if isRunningBackgroundTask {
            // Terminate the app if this is called from the same thread as the running background task.
            if #available(iOS 10.0, *) {
                Dispatch.dispatchPrecondition(condition: .notOnQueue(.global()))
            } else {
                // Fallback on earlier versions
            }
            completion(.failure(BluejayError.backgroundTaskRunning))
            return
        }

        if let peripheral = connectedPeripheral {
            peripheral.restoreListen(to: characteristicIdentifier, completion: completion)
        } else {
            completion(.failure(BluejayError.notConnected))
        }
    }

    /**
     Check if a peripheral is listening to a specific characteristic.
     
     - Parameters:
       - to: The characteristic we want to check.
     */
    public func isListening(to characteristicIdentifier: CharacteristicIdentifier) throws -> Bool {
        guard let periph = connectedPeripheral else {
            throw BluejayError.notConnected
        }
        return periph.isListening(to: characteristicIdentifier)
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
        completionOnMainThread: @escaping (RunResult<Void>) -> Void) {
        if isRunningBackgroundTask {
            completionOnMainThread(.failure(BluejayError.multipleBackgroundTaskNotSupported))
            return
        }

        if queue.isDisconnectionQueued {
            completionOnMainThread(.failure(BluejayError.disconnectQueued))
            return
        }

        isRunningBackgroundTask = true

        if let peripheral = connectedPeripheral {
            DispatchQueue.global().async { [weak self] in
                guard let weakSelf = self else {
                    return
                }

                let synchronizedPeripheral = SynchronizedPeripheral(parent: peripheral)

                do {
                    weakSelf.register(observer: synchronizedPeripheral)
                    try backgroundTask(synchronizedPeripheral)

                    DispatchQueue.main.async {
                        weakSelf.isRunningBackgroundTask = false
                        completionOnMainThread(.success(()))
                        weakSelf.unregister(observer: synchronizedPeripheral)
                    }
                } catch let error as NSError {
                    DispatchQueue.main.async {
                        weakSelf.isRunningBackgroundTask = false
                        completionOnMainThread(.failure(error))
                        weakSelf.unregister(observer: synchronizedPeripheral)

                        if error == BluejayError.notConnected as NSError {
                            weakSelf.disconnectCleanUp?()
                            weakSelf.disconnectCleanUp = nil
                        }
                    }
                }
            }
        } else {
            isRunningBackgroundTask = false
            completionOnMainThread(.failure(BluejayError.notConnected))
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
        completionOnMainThread: @escaping (RunResult<Result>) -> Void) {
        if isRunningBackgroundTask {
            completionOnMainThread(.failure(BluejayError.multipleBackgroundTaskNotSupported))
            return
        }

        if queue.isDisconnectionQueued {
            completionOnMainThread(.failure(BluejayError.disconnectQueued))
            return
        }

        isRunningBackgroundTask = true

        if let peripheral = connectedPeripheral {
            DispatchQueue.global().async { [weak self] in
                guard let weakSelf = self else {
                    return
                }

                let synchronizedPeripheral = SynchronizedPeripheral(parent: peripheral)

                do {
                    weakSelf.register(observer: synchronizedPeripheral)
                    let result = try backgroundTask(synchronizedPeripheral)

                    DispatchQueue.main.async {
                        weakSelf.isRunningBackgroundTask = false
                        completionOnMainThread(.success(result))
                        weakSelf.unregister(observer: synchronizedPeripheral)
                    }
                } catch let error as NSError {
                    DispatchQueue.main.async {
                        weakSelf.isRunningBackgroundTask = false
                        completionOnMainThread(.failure(error))
                        weakSelf.unregister(observer: synchronizedPeripheral)

                        if error == BluejayError.notConnected as NSError {
                            weakSelf.disconnectCleanUp?()
                            weakSelf.disconnectCleanUp = nil
                        }
                    }
                }
            }
        } else {
            isRunningBackgroundTask = false
            completionOnMainThread(.failure(BluejayError.notConnected))
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
        completionOnMainThread: @escaping (RunResult<Result>) -> Void) {
        if isRunningBackgroundTask {
            completionOnMainThread(.failure(BluejayError.multipleBackgroundTaskNotSupported))
            return
        }

        if queue.isDisconnectionQueued {
            completionOnMainThread(.failure(BluejayError.disconnectQueued))
            return
        }

        isRunningBackgroundTask = true

        if let peripheral = connectedPeripheral {
            DispatchQueue.global().async { [weak self] in
                guard let weakSelf = self else {
                    return
                }

                let synchronizedPeripheral = SynchronizedPeripheral(parent: peripheral)

                do {
                    weakSelf.register(observer: synchronizedPeripheral)
                    let result = try backgroundTask(synchronizedPeripheral, userData)

                    DispatchQueue.main.async {
                        weakSelf.isRunningBackgroundTask = false
                        completionOnMainThread(.success(result))
                        weakSelf.unregister(observer: synchronizedPeripheral)
                    }
                } catch let error as NSError {
                    DispatchQueue.main.async {
                        weakSelf.isRunningBackgroundTask = false
                        completionOnMainThread(.failure(error))
                        weakSelf.unregister(observer: synchronizedPeripheral)

                        if error == BluejayError.notConnected as NSError {
                            weakSelf.disconnectCleanUp?()
                            weakSelf.disconnectCleanUp = nil
                        }
                    }
                }
            }
        } else {
            isRunningBackgroundTask = false
            completionOnMainThread(.failure(BluejayError.notConnected))
        }
    }

    // MARK: - Helpers

    /**
     A helper function to take an array of Sendables and combine their data together.
     
     - Parameter sendables: An array of Sendables whose Data should be appended in the order of the given array.
     
     - Returns: The resulting data of all the Sendables combined in the order of the passed in array.
     */
    public static func combine(sendables: [Sendable]) -> Data {
        var data = Data()

        for sendable in sendables {
            data.append(sendable.toBluetoothData())
        }

        return data
    }

}

// MARK: - CBCentralManagerDelegate

extension Bluejay: CBCentralManagerDelegate {

    /**
     Bluejay uses this to figure out whether Bluetooth is available or not.
     
     - If Bluetooth is available for the first time, start running the queue.
     - If Bluetooth is available for the first time and the app is already connected, then this is a state restoration event. Try listen restoration if possible.
     - If Bluetooth is turned off, cancel everything with the `bluetoothUnavailable` error and disconnect.
     - Broadcast state changes to observers.
     */
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let backgroundTask = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)

        if #available(iOS 10.0, *) {
            log("CBCentralManager state updated: \(central.state.string())")
        } else {
            // Fallback on earlier versions
            log("CBCentralManager state updated: \(central.state)")
        }

        let updateStateCompletion = {
            switch central.state {
            case .poweredOn:
                if let connectingPeripheralAtRestoration = self.connectingPeripheralAtRestoration {
                    guard let backgroundRestorer = self.backgroundRestorer else {
                        fatalError("No background restorer found during state restoration.")
                    }

                    self.connect(connectingPeripheralAtRestoration.uuid, timeout: .seconds(15), completion: { (result) in
                        switch result {
                        case .success(let peripheral):
                            log("Did restore connection to peripheral: \(peripheral.name)")

                            let completion = backgroundRestorer.didRestoreConnection(to: peripheral)
                            completion()
                        case .failure(let error):
                            log("Did fail to to restore connection with error: \(error.localizedDescription)")

                            let completion = backgroundRestorer.didFailToRestoreConnection(
                                to: connectingPeripheralAtRestoration,
                                error: error
                            )
                            completion()
                        }
                    })

                    // We don't broadcast the Bluetooth available event here because it is important to distinguish the difference between Bluetooth becoming available from normal usage versue Bluetooth becoming available due to a background restoration.
                } else if let connectedPeripheral = self.connectedPeripheral {
                    guard let backgroundRestorer = self.backgroundRestorer else {
                        fatalError("No background restorer found during state restoration.")
                    }

                    log("Did restore connection to peripheral: \(connectedPeripheral.name)")

                    let completion = backgroundRestorer.didRestoreConnection(to: connectedPeripheral)
                    completion()

                    // We don't broadcast the Bluetooth available event here because it is important to distinguish the difference between Bluetooth becoming available from normal usage versue Bluetooth becoming available due to a background restoration.
                } else {
                    for observer in self.observers {
                        observer.weakReference?.bluetoothAvailable(true)
                    }
                }
            default:
                self.cancelEverything(error: BluejayError.bluetoothUnavailable)

                self.connectingPeripheral = nil
                self.connectedPeripheral = nil

                for observer in self.observers {
                    observer.weakReference?.bluetoothAvailable(false)
                }
            }

            UIApplication.shared.endBackgroundTask(backgroundTask)
        }

        if central.state == .poweredOn {
            if connectingPeripheralAtRestoration != nil {
                log("Background restore to a connecting state.")

                // Clear everything that might be in the queue before completing background restorations.
                cancelEverything(error: BluejayError.backgroundRestorationInProgress, shouldDisconnect: false)

                // Safe to start the queue once it is emptied to allow background restorations, as well as subsequent user requests to complete.
                queue.start()

                updateStateCompletion()
            } else if connectedPeripheral != nil {
                log("Background restore to a connected state.")

                // Clear everything that might be in the queue before completing background and listen restorations.
                cancelEverything(error: BluejayError.backgroundRestorationInProgress, shouldDisconnect: false)

                // Safe to start the queue once it is emptied to allow listen and background restorations, as well as subsequent user requests to complete.
                queue.start()

                do {
                    try requestListenRestoration(completion: {
                        updateStateCompletion()
                    })
                } catch {
                    log("Failed to complete listen restoration with error: \(error)")
                    updateStateCompletion()
                }
            } else {
                // First foreground initialization, or toggling of Bluetooth from iOS Control Center or Settings.
                queue.start()
                updateStateCompletion()
            }
        } else {
            updateStateCompletion()
        }
    }

    /**
     Examine the listen cache in `UserDefaults` to determine whether there are any listens that might need restoration.
     */
    private func requestListenRestoration(completion: () -> Void) throws {
        log("Starting listen restoration.")

        guard
            let listenCaches = UserDefaults.standard.dictionary(forKey: Constant.listenCaches),
            let restoreIdentifier = restoreIdentifier,
            let cacheData = listenCaches[restoreIdentifier] as? [Data]
        else {
            log("No listens to restore.")
            completion()
            return
        }

        let decoder = JSONDecoder()

        for data in cacheData {
            do {
                let listenCache = try decoder.decode(ListenCache.self, from: data)

                log("Listen cache to restore: \(listenCache)")

                let serviceIdentifier = ServiceIdentifier(uuid: listenCache.serviceUUID)
                let characteristicIdentifier = CharacteristicIdentifier(uuid: listenCache.characteristicUUID, service: serviceIdentifier)

                if let listenRestorer = listenRestorer {
                    // If true, assume the listen restorable delegate will restore the listen accordingly, otherwise end the listen.
                    if !listenRestorer.willRestoreListen(on: characteristicIdentifier) {
                        endListen(to: characteristicIdentifier)
                    }
                } else {
                    // If there is no listen restorable delegate, end the listen as well.
                    endListen(to: characteristicIdentifier)
                }
            } catch {
                throw BluejayError.listenCacheDecoding(error)
            }
        }

        log("Listen restoration has queued all necessary end listens as well as restored any provided callbacks.")

        completion()
    }

    /**
     If Core Bluetooth will restore state, update Bluejay's internal states to match the states of the Core Bluetooth stack by assigning the peripheral to `connectingPeripheral` or `connectedPeripheral`, or niling them out, depending on what the restored `CBPeripheral` state is.
     */
    public func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        log("Will restore state.")

        shouldRestoreState = false

        defer {
            if startupBackgroundTask != UIBackgroundTaskInvalid {
                log("Cancelling startup background task.")
                UIApplication.shared.endBackgroundTask(startupBackgroundTask)
            }
        }

        guard let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral], let cbPeripheral = peripherals.first else {
            log("No peripherals found during state restoration.")
            return
        }

        let peripheral = Peripheral(bluejay: self, cbPeripheral: cbPeripheral)

        precondition(peripherals.count == 1, "Invalid number of peripheral to restore.")

        log("Peripheral state to restore: \(cbPeripheral.state.string())")

        switch cbPeripheral.state {
        case .connecting:
            precondition(connectedPeripheral == nil,
                         "Connected peripheral is not nil during willRestoreState for state: connecting.")
            connectingPeripheralAtRestoration = peripheral
        case .connected:
            precondition(connectingPeripheral == nil,
                         "Connecting peripheral is not nil during willRestoreState for state: connected.")
            connectedPeripheral = peripheral
        case .disconnecting:
            precondition(connectingPeripheral == nil,
                         "Connecting peripheral is not nil during willRestoreState for state: disconnecting.")
        case .disconnected:
            precondition(connectingPeripheral == nil && connectedPeripheral == nil,
                         "Connecting and connected peripherals are not nil during willRestoreState for state: disconnected.")
        }
    }

    /**
     When connected, update Bluejay's states by updating the values for `connectingPeripheral`, `connectedPeripheral`, and `shouldAutoReconnect`. Also, make sure to broadcast the event to observers, and notify the queue so that the current operation in-flight can process this event and get a chance to finish.
    */
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let backgroundTask =  UIApplication.shared.beginBackgroundTask(expirationHandler: nil)

        log("Did connect to: \(peripheral.name ?? peripheral.identifier.uuidString)")

        connectingCallback = nil

        connectedPeripheral = connectingPeripheral
        connectingPeripheral = nil

        precondition(connectedPeripheral != nil, "Connected peripheral is assigned a nil value despite Bluejay has successfully finished a connection.")

        // Don't broadcast a connected event if state restoration is able to complete the connection of a connecting peripheral, as the user should be using the background restoration delegation in that case.
        if connectingPeripheralAtRestoration == nil {
            for observer in observers {
                observer.weakReference?.connected(to: connectedPeripheral!)
            }
        } else {
            connectingPeripheralAtRestoration = nil
        }

        shouldAutoReconnect = true
        log("Should auto-reconnect: \(shouldAutoReconnect)")

        queue.process(event: .didConnectPeripheral(connectedPeripheral!), error: nil)

        UIApplication.shared.endBackgroundTask(backgroundTask)
    }

    /**
     Handle a disconnection event from Core Bluetooth by figuring out what kind of disconnection it is (planned or unplanned), and updating Bluejay's internal state and sending notifications as appropriate.
    */
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        // swiftlint:disable:previous cyclomatic_complexity
        let backgroundTask =  UIApplication.shared.beginBackgroundTask(expirationHandler: nil)

        let peripheralString = peripheral.name ?? peripheral.identifier.uuidString
        let errorString = error?.localizedDescription

        if let errorMessage = errorString {
            log("Central manager did disconnect from \(peripheralString) with error: \(errorMessage)")
        } else {
            log("Central manager did disconnect from \(peripheralString) without errors.")
        }

        guard let disconnectedPeripheral = connectingPeripheral ?? connectedPeripheral else {
            log("Central manager disconnected from an unexpected peripheral.")
            return
        }

        let wasRestoringConnectingPeripheral = connectingPeripheralAtRestoration != nil
        let wasConnecting = isConnecting
        let wasConnected = isConnected

        if wasRestoringConnectingPeripheral {
            log("Peripheral was still connecting during background restoration before disconnect.")
        } else if wasConnecting {
            log("Peripheral was still connecting before disconnect.")
        } else if wasConnected {
            log("Peripheral was connected before disconnect.")
        }

        connectingPeripheralAtRestoration = nil
        connectingPeripheral = nil
        connectedPeripheral = nil

        var isExpectedDisconnect = false

        if (!isDisconnecting && !queue.isRunningQueuedDisconnection) || wasRestoringConnectingPeripheral {
            log("The disconnect is unexpected.")

            isExpectedDisconnect = false
            shouldAutoReconnect = !wasRestoringConnectingPeripheral

            log("Should auto-reconnect: \(shouldAutoReconnect)")

            if wasConnected {
                cancelEverything(error: BluejayError.notConnected)
            }
        } else {
            log("The disconnect is expected.")

            isExpectedDisconnect = true
            shouldAutoReconnect = false

            log("Should auto-reconnect: \(shouldAutoReconnect)")
        }

        disconnectCleanUp = { [weak self] in
            guard let weakSelf = self else {
                return
            }

            log("Starting disconnect clean up...")

            var connectingError: Error?

            if wasConnecting || weakSelf.queue.isRunningQueuedDisconnection {
                precondition(
                    !weakSelf.queue.isEmpty,
                    "Queue should not be emptied at the beginning of disconnect clean up when Bluejay was still connecting or has started a queued disconnection."
                )

                if wasConnecting {
                    log("Disconnect clean up: delivering expected disconnected event back to the pending connection in the queue...")

                    if let connection = weakSelf.queue.first as? Connection {
                        if case let .stopping(error) = connection.state {
                            connectingError = error
                        }
                    }

                } else if weakSelf.queue.isRunningQueuedDisconnection {
                    log("Disconnect clean up: delivering expected disconnected event back to the queued disconnection in the queue...")
                }

                // Allow the Connection or Disconnection operation to finish its cancellation, trigger its callback, and continue cancelling any remaining operations in the queue.
                weakSelf.queue.process(event: .didDisconnectPeripheral(disconnectedPeripheral), error: nil)
            } else if wasConnected {
                precondition(weakSelf.queue.isEmpty, "Queue should be emptied before notifying and invoking all disconnect observers and callbacks.")
            }

            if wasRestoringConnectingPeripheral {
                log("Disconnect clean up: disconnected while restoring a connecting peripheral, will not auto-reconnect.")

                guard let connectingError = connectingError else {
                    preconditionFailure(
                        "Missing connecting error at the end of a disconnect clean up after cancelling a connecting peripheral during state restoration."
                    )
                }

                weakSelf.connectingCallback?(.failure(connectingError))
                weakSelf.connectingCallback = nil
            } else {
                log("Disconnect clean up: notifying all connection observers.")

                for observer in weakSelf.observers {
                    observer.weakReference?.disconnected(from: disconnectedPeripheral)
                }

                log("Disconnect clean up: should auto-reconnect: \(weakSelf.shouldAutoReconnect)")

                if let disconnectHandler = weakSelf.disconnectHandler {
                    log("Disconnect clean up: calling the disconnect handler.")
                    switch disconnectHandler.didDisconnect(from: disconnectedPeripheral, with: error, willReconnect: weakSelf.shouldAutoReconnect) {
                    case .noChange:
                        log("Disconnect handler will not change auto-reconnect.")
                    case .change(let autoReconnect):
                        weakSelf.shouldAutoReconnect = autoReconnect
                        log("Disconnect handler changing auto-reconnect to: \(weakSelf.shouldAutoReconnect)")
                    }
                }

                if isExpectedDisconnect {
                    log("Disconnect clean up: calling the explicit disconnect callback if it is provided.")
                    weakSelf.disconnectCallback?(.disconnected(disconnectedPeripheral))
                    weakSelf.disconnectCallback = nil
                }

                if wasConnecting {
                    guard let connectingError = connectingError else {
                        preconditionFailure("Missing connecting error at the end of a disconnect clean up after cancelling a pending connection.")
                    }

                    log("Disconnect clean up: calling the connecting callback if it is provided.")
                    weakSelf.connectingCallback?(.failure(connectingError))
                    weakSelf.connectingCallback = nil
                }

                weakSelf.isDisconnecting = false

                if weakSelf.shouldAutoReconnect {
                    log("Disconnect clean up: issuing reconnect to: \(peripheral.name ?? peripheral.identifier.uuidString)")
                    weakSelf.connect(
                        PeripheralIdentifier(uuid: peripheral.identifier),
                        timeout: weakSelf.previousConnectionTimeout ?? .none,
                        completion: {_ in }
                    )
                }
            }

            log("End of disconnect clean up.")

            UIApplication.shared.endBackgroundTask(backgroundTask)
        }

        if isRunningBackgroundTask {
            log("Delaying disconnect clean up due to running background task.")
        } else {
            disconnectCleanUp?()
        }
    }

    /**
     This mostly happens when either the Bluetooth device or the Core Bluetooth stack somehow only partially completes the negotiation of a connection. For simplicity, Bluejay is currently treating this as a disconnection event, so it can perform all the same clean up logic.
     */
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        // Use the same clean up logic provided in the did disconnect callback.
        centralManager(central, didDisconnectPeripheral: peripheral, error: error)
    }

    /**
     This should only be called when the current operation in the queue is a `Scan` task.
    */
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        // let peripheralString = advertisementData[CBAdvertisementDataLocalNameKey] ?? peripheral.identifier.uuidString
        // log("Did discover: \(peripheralString)")

        queue.process(event: .didDiscoverPeripheral(peripheral, advertisementData, RSSI), error: nil)
    }

}

/// Allows Bluejay to receive events and delegation from its queue.
extension Bluejay: QueueObserver {

    /// Support for the will connect state that CBCentralManagerDelegate does not have.
    func willConnect(to peripheral: CBPeripheral) {
        connectingPeripheral = Peripheral(bluejay: self, cbPeripheral: peripheral)
    }

}

/// Convenience function to log information specific to Bluejay within the framework. We have plans to improve logging significantly in the near future.
func log(_ string: String) {
    debugPrint("[Bluejay-Debug] \(string)")
}
//swiftlint:disable:this file_length
