//
//  Bluejay.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-03.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import UIKit
import CoreBluetooth

/**
 Bluejay is a simple wrapper around CoreBluetooth that focuses on making a common usage case as straight forward as possible: a single connected peripheral that the user is interacting with regularly (think most personal electronics devices that have an associated iOS app: fitness trackers, guitar amps, etc).

 It also supports a few other niceties for simplifying usage, including automatic discovery of services and characteristics as they are used, as well as supporting a background task mode where the interaction with the device can be written as synchronous calls running on a background thread to avoid callback pyramids of death, or heavily chained promises.
 */
public class Bluejay: NSObject { //swiftlint:disable:this type_body_length

    // MARK: - Private Properties

    /// Internal reference to CoreBluetooth's CBCentralManager.
    private var cbCentralManager: CBCentralManager!

    /// Contains the operations to execute in FIFO order.
    private var queue: Queue!

    /// List of weak references to objects interested in receiving notifications on Bluetooth connection events and state changes.
    private var connectionObservers = [WeakConnectionObserver]()

    /// List of weak references to objects interested in receiving notifications on RSSI reads.
    private var rssiObservers: [WeakRSSIObserver] = []

    /// List of weak references to objects interested in receiving notifications on services changes.
    private var serviceObservers: [WeakServiceObserver] = []

    /// List of weak references to objects interested in receiving notifications on log file changes.
    private var logObservers: [WeakLogObserver] = []

    /// Reference to a peripheral that is still connecting. If this is nil, then the peripheral should either be disconnected or connected. This is used to help determine the state of the peripheral's connection.
    private var connectingPeripheral: Peripheral?

    /// Reference to a peripheral that is connected. If this is nil, then the peripheral should either be disconnected or still connecting. This is used to help determine the state of the peripheral's connection.
    private var connectedPeripheral: Peripheral?

    /// The previous connection timeout used.
    private var previousConnectionTimeout: Timeout?

    /// Cache for a connection callback and used if the connection fails to complete.
    private var connectingCallback: ((ConnectionResult) -> Void)?

    /// Cache for an explicit disconnect callback if provided.
    private var disconnectCallback: ((DisconnectionResult) -> Void)?

    /// Reference to a disconnect handler.
    private weak var disconnectHandler: DisconnectHandler?

    /// Allows caching and defering disconnect notifications and final clean ups when there is a disconnection while running a Bluejay background task.
    private var disconnectCleanUp: (() -> Void)?

    /// The value for CBCentralManagerOptionRestoreIdentifierKey.
    private var restoreIdentifier: RestoreIdentifier?

    /// The delegate responsible for handling background restoration results.
    private weak var backgroundRestorer: BackgroundRestorer?

    /// The delegate responsible for handling listen restoration results.
    private weak var listenRestorer: ListenRestorer?

    /// Determines whether Bluejay is currently performing state restoration.
    private var isRestoring = false

    /// Reference to the startup, **not Bluejay**, background task used for supporting state restoration.
    private var startupBackgroundTask: UIBackgroundTaskIdentifier = UIBackgroundTaskIdentifier.invalid

    /// True when Bluejay, **not startup**, background task is running, and helps prevent calling regular read/write/listen.
    private var isRunningBackgroundTask = false

    /**
     * Reference to a connecting peripheral during backgrouundrestoration, this is different from the normal connecting peripheral since background restoration requires an explicit connect call to restore the connecting state, and that connect call will be blocked due to multiple connect prevention if we use the normal connecting peripheral reference.
     */
    private var connectingPeripheralAtRestoration: Peripheral?

    /// Only **not nil** when background restoration is restoring into a disconnecting state.
    private var disconnectingPeripheralAtRestoration: Peripheral?

    /// Only **not nil** when background restoration is restoring into a disconnected state.
    private var disconnectedPeripheralAtRestoration: Peripheral?

    /// Convenient accessor to app document directory.
    private var documentUrl: URL? {
        do {
            return try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true)
        } catch {
            return nil
        }
    }

    /// File name for the log file.
    private let logFileName = "bluejay_debug.txt"

    /// Source and descriptor for setting up the monitoring of changes in the log file.
    private var logFileMonitorSource: DispatchSourceFileSystemObject?
    private var logFileDescriptor: CInt = 0

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

    /// Allows checking whether Bluejay has background restoration enabled.
    public var isBackgroundRestorationEnabled: Bool {
        return restoreIdentifier != nil
    }

    /// Enables disconnection errors or arguments to "cancelEverything" also being broadcast to active listeners, to allow them to perform cleanup or shutdown
    /// operations.
    ///
    /// Note: Currently defaults to false, to match original behaviour, because this could be quite disruptive to code that was written assuming this isn't true.
    /// Arguably should default to true, since there are some situations (such listens in background tasks without timeouts) where this is required for correct
    /// behaviour, and it may change eventually.
    public var broadcastErrorsToListeners: Bool = false

    // MARK: - Logging

    /**
     *  Log a message to the logObservers, or debug consiole if there is none
     *
     * - Parameter string: the message you want to log.
     */
    internal func debugLog(_ string: String) {
        if logObservers.isEmpty {
            NSLog(string)
        }

        var missing = false

        for weakObserver in logObservers {
            if let observer = weakObserver.weakReference {
                observer.debug(string)
            } else {
                missing = true
            }
        }

        if missing {
            logObservers = logObservers.filter { $0.weakReference != nil }

            if logObservers.isEmpty {
                NSLog(string)
            }
        }
    }

    // MARK: - Initialization

    /**
     Initializing a Bluejay instance will not yet initialize the CoreBluetooth stack. An explicit `start` call after Bluejay is intialized will then initialize the CoreBluetooth stack and is required because in cases where a state resotration is trying to restore a listen on a characteristic, a listen restorer must be available before the CoreBluetooth stack is re-initialized. This two-step startup allows you to prepare and gaurantee the setup of your listen restorer in between the initialization of Bluejay and the initialization of the CoreBluetooth stack.
     */
    public init(logObserver: LogObserver? = nil) {
        super.init()

        if let logObserver = logObserver {
            register(logObserver: logObserver)
        }

        debugLog("Bluejay initialized with UUID: \(uuid.uuidString).")
    }

    deinit {
        cancelEverything()
        debugLog("Deinit Bluejay with UUID: \(uuid.uuidString).")
    }

    /**
     Starting Bluejay will initialize the CoreBluetooth stack. Simply initializing a Bluejay instance without calling this function will not initialize the CoreBluetooth stack. An explicit start call is required so that we can also support proper background restoration, where CoreBluetooth must be initialized in the AppDelegate's application(_:didFinishLaunchingWithOptions:) for both starting an iOS background task and for parsing the restore identifier.

     - Parameters:
        - mode: CoreBluetooth initialization modes and options.
    */
    public func start(mode: StartMode = .new(.default)) {
        queue = Queue(bluejay: self)

        switch mode {
        case .new(let startOptions):
            register(connectionObserver: queue)

            var managerOptions: [String: Any] = [CBCentralManagerOptionShowPowerAlertKey: startOptions.enableBluetoothAlert]

            switch startOptions.backgroundRestore {
            case .disable:
                break
            case .enable(let backgroundRestoreConfig):
                checkBackgroundSupportForBluetooth()
                restoreIdentifier = backgroundRestoreConfig.restoreIdentifier
                backgroundRestorer = backgroundRestoreConfig.backgroundRestorer
                listenRestorer = backgroundRestoreConfig.listenRestorer
                isRestoring = backgroundRestoreConfig.isRestoringFromBackground
                managerOptions[CBCentralManagerOptionRestoreIdentifierKey] = restoreIdentifier

                debugLog("Background restoration enabled with restore identifier: \(backgroundRestoreConfig.restoreIdentifier)")
            }

            if isRestoring {
                debugLog("Begin startup background task for restoring CoreBluetooth.")
                startupBackgroundTask = UIApplication.shared.beginBackgroundTask(expirationHandler: {
                    self.cancelEverything(error: BluejayError.startupBackgroundTaskExpired, shouldDisconnect: false)
                })
            }

            cbCentralManager = CBCentralManager(
                delegate: self,
                queue: .main,
                options: managerOptions
            )

            debugLog("CBCentralManager initialized.")
        case .use(let manager, let peripheral):
            cbCentralManager = manager

            if let peripheral = peripheral {
                connectedPeripheral = Peripheral(delegate: self, cbPeripheral: peripheral, bluejay: self)
                peripheral.delegate = connectedPeripheral
            }

            queue.start()
        }

        debugLog("Bluejay with UUID: \(uuid.uuidString) started.")
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
            clearAllRestorationPeripherals()
            clearAllNonRestorationPeripherals()

            cbCentralManager.delegate = nil
            cbCentralManager = nil

            debugLog("Bluejay with UUID: \(uuid.uuidString) stopped.")
        }

        cancelEverything(error: BluejayError.stopped, shouldDisconnect: false)

        connectionObservers.removeAll()
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
            debugLog("""
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
        debugLog("Cancel everything called with error: \(error.localizedDescription), shouldDisconnect: \(shouldDisconnect)")

        if isConnecting {
            debugLog("Cancel everything called while still connecting...")

            isDisconnecting = true
            shouldAutoReconnect = false

            debugLog("Should auto-reconnect: \(shouldAutoReconnect)")
        }

        if broadcastErrorsToListeners {
            connectedPeripheral?.broadcastErrorToListeners(error)
        }
        queue.cancelAll(error: error)

        if isConnected && shouldDisconnect {
            debugLog("Cancel everything will now disconnect a connected peripheral...")

            isDisconnecting = true
            shouldAutoReconnect = false

            debugLog("Should auto-reconnect: \(shouldAutoReconnect)")

            cbCentralManager.cancelPeripheralConnection(connectedPeripheral!.cbPeripheral)
        }
    }

    // MARK: - Events Registration

    /**
     Register for notifications on Bluetooth connection events and state changes. Unregistering is not required, Bluejay will unregister for you if the observer is no longer in memory.

     - Parameter connectionObserver: object interested in receiving Bluejay's Bluetooth connection related events.
     */
    public func register(connectionObserver: ConnectionObserver) {
        connectionObservers = connectionObservers.filter { $0.weakReference != nil && $0.weakReference !== connectionObserver }
        connectionObservers.append(WeakConnectionObserver(weakReference: connectionObserver))

        if cbCentralManager != nil {
            connectionObserver.bluetoothAvailable(cbCentralManager.state == .poweredOn)
        }

        if let connectedPeripheral = connectedPeripheral, !isDisconnecting {
            connectionObserver.connected(to: connectedPeripheral.identifier)
        }
    }

    /**
     Unregister for notifications on Bluetooth connection events and state changes. Unregistering is not required, Bluejay will unregister for you if the observer is no longer in memory.

     - Parameter connectionObserver: object no longer interested in receiving Bluejay's connection related events.
     */
    public func unregister(connectionObserver: ConnectionObserver) {
        connectionObservers = connectionObservers.filter { $0.weakReference != nil && $0.weakReference !== connectionObserver }
    }

    /**
     Register for notifications when `readRSSI` is called. Unregistering is not required, Bluejay will unregister for you if the observer is no longer in memory.

     - Parameter rssiObserver: object interested in receiving Bluejay's `readRSSI` response.
     */
    public func register(rssiObserver: RSSIObserver) {
        rssiObservers = rssiObservers.filter { $0.weakReference != nil && $0.weakReference !== rssiObserver }
        rssiObservers.append(WeakRSSIObserver(weakReference: rssiObserver))
    }

    /**
     Unregister for notifications when `readRSSI` is called. Unregistering is not required, Bluejay will unregister for you if the observer is no longer in memory.

     - Parameter rssiObserver: object no longer interested in receiving Bluejay's `readRSSI` response.
     */
    public func unregister(rssiObserver: RSSIObserver) {
        rssiObservers = rssiObservers.filter { $0.weakReference != nil && $0.weakReference !== rssiObserver }
    }

    /**
     Register for notifications when a connected peripheral's services change. Unregistering is not required, Bluejay will unregister for you if the observer is no longer in memory.

     - Parameter serviceObserver: object interested in receiving the connected peripheral's did modify services event.
     */
    public func register(serviceObserver: ServiceObserver) {
        serviceObservers = serviceObservers.filter { $0.weakReference != nil && $0.weakReference !== serviceObserver }
        serviceObservers.append(WeakServiceObserver(weakReference: serviceObserver))
    }

    /**
     Unregister for notifications when a connected peripheral's services change. Unregistering is not required, Bluejay will unregister for you if the observer is no longer in memory.

     - Parameter serviceObserver: object no longer interested in receiving the connected peripheral's did modify services event.
     */
    public func unregister(serviceObserver: ServiceObserver) {
        serviceObservers = serviceObservers.filter { $0.weakReference != nil && $0.weakReference !== serviceObserver }
    }

    /**
     Register for notifications when debug logs occur inside the library. Unregistering is not required, Bluejay will unregister for you if the observer is no longer in memory. If no log
        observers are registeres, debug logs will be printed with NSLog()

     - Parameter logObserver: object interested in receiving log file updates.
     */
    public func register(logObserver: LogObserver) {
        logObservers = logObservers.filter { $0.weakReference != nil && $0.weakReference !== logObserver }
        logObservers.append(WeakLogObserver(weakReference: logObserver))
    }

    /**
     Unregister for notifications when ebug logs occur inside the library Unregistering is not required, Bluejay will unregister for you if the observer is no longer in memory.

     - Parameter logObserver: object no longer interested in notifications when the log file is updated.
     */
    public func unregister(logObserver: LogObserver) {
        logObservers = logObservers.filter { $0.weakReference != nil && $0.weakReference !== logObserver }
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
        Dispatch.dispatchPrecondition(condition: .onQueue(.main))

        if isRunningBackgroundTask {
            stopped([], BluejayError.backgroundTaskRunning)
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
        Dispatch.dispatchPrecondition(condition: .onQueue(.main))

        if isRunningBackgroundTask {
            debugLog("Error: You cannot stop a scan while a background task is still running.")
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
        timeout: Timeout = .none,
        warningOptions: WarningOptions? = nil,
        completion: @escaping (ConnectionResult) -> Void) {
        Dispatch.dispatchPrecondition(condition: .onQueue(.main))

        previousConnectionTimeout = timeout

        if isRunningBackgroundTask {
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
        Dispatch.dispatchPrecondition(condition: .onQueue(.main))

        if isRunningBackgroundTask {
            completion?(.failure(BluejayError.backgroundTaskRunning))
            return
        }

        if isDisconnecting || (immediate == false && queue.isDisconnectionQueued) {
            completion?(.failure(BluejayError.multipleDisconnectNotSupported))
            return
        }

        if isConnecting || isConnected {
            debugLog("Explicit disconnect called.")

            disconnectCallback = completion
            shouldAutoReconnect = false

            if immediate {
                isDisconnecting = true
                cancelEverything(error: BluejayError.explicitDisconnect)
            } else {
                if let peripheral = connectingPeripheral?.cbPeripheral ?? connectedPeripheral?.cbPeripheral {
                    queue.add(Disconnection(peripheral: peripheral, manager: cbCentralManager, callback: completion))
                } else {
                    debugLog("Cannot disconnect: there is no connected nor connecting peripheral.")
                    completion?(.failure(BluejayError.notConnected))
                }
            }
        } else {
            debugLog("Cannot disconnect: there is no connected nor connecting peripheral.")
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
        Dispatch.dispatchPrecondition(condition: .onQueue(.main))

        if isRunningBackgroundTask {
            completion(.failure(BluejayError.backgroundTaskRunning))
            return
        }

        if let peripheral = connectedPeripheral {
            peripheral.read(from: characteristicIdentifier, completion: completion)
        } else {
            debugLog("Cannot request read on \(characteristicIdentifier.description): \(BluejayError.notConnected.localizedDescription)")
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
    public func write<S: Sendable>(
        to characteristicIdentifier: CharacteristicIdentifier,
        value: S,
        type: CBCharacteristicWriteType = .withResponse,
        completion: @escaping (WriteResult) -> Void) {
        Dispatch.dispatchPrecondition(condition: .onQueue(.main))

        if isRunningBackgroundTask {
            completion(.failure(BluejayError.backgroundTaskRunning))
            return
        }

        if let peripheral = connectedPeripheral {
            peripheral.write(to: characteristicIdentifier, value: value, type: type, completion: completion)
        } else {
            debugLog("Cannot request write on \(characteristicIdentifier.description): \(BluejayError.notConnected.localizedDescription)")
            completion(.failure(BluejayError.notConnected))
        }
    }

    /**
     Listen for notifications on the specified characteristic.

     - Parameters:
        - characteristicIdentifier: The characteristic to listen to.
        - completion: Called with the result of the attempt to listen for notifications on the specified characteristic.
     */
    public func listen<R: Receivable>(
        to characteristicIdentifier: CharacteristicIdentifier,
        multipleListenOption option: MultipleListenOption = .trap,
        completion: @escaping (ReadResult<R>) -> Void) {
        Dispatch.dispatchPrecondition(condition: .onQueue(.main))

        if isRunningBackgroundTask {
            completion(.failure(BluejayError.backgroundTaskRunning))
            return
        }

        if let peripheral = connectedPeripheral {
            peripheral.listen(to: characteristicIdentifier, multipleListenOption: option, completion: completion)
        } else {
            debugLog("Cannot request listen on \(characteristicIdentifier.description): \(BluejayError.notConnected.localizedDescription)")
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
        Dispatch.dispatchPrecondition(condition: .onQueue(.main))

        if isRunningBackgroundTask {
            completion?(.failure(BluejayError.backgroundTaskRunning))
            return
        }

        if let peripheral = connectedPeripheral {
            peripheral.endListen(to: characteristicIdentifier, error: nil, completion: completion)
        } else {
            debugLog("Cannot request end listen on \(characteristicIdentifier.description): \(BluejayError.notConnected.localizedDescription)")
            completion?(.failure(BluejayError.notConnected))
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

    /**
     Attempts to read the RSSI (signal strength) of the currently connected peripheral.

     - Warning: Will throw if called while a Bluejay background task is running, or if not connected.
     */
    public func readRSSI() throws {
        Dispatch.dispatchPrecondition(condition: .onQueue(.main))

        if isRunningBackgroundTask {
            throw BluejayError.backgroundTaskRunning
        }

        if let peripheral = connectedPeripheral {
            peripheral.readRSSI()
        } else {
            throw BluejayError.notConnected
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
                    weakSelf.register(connectionObserver: synchronizedPeripheral)
                    try backgroundTask(synchronizedPeripheral)

                    DispatchQueue.main.async {
                        weakSelf.isRunningBackgroundTask = false
                        completionOnMainThread(.success(()))
                        weakSelf.unregister(connectionObserver: synchronizedPeripheral)
                    }
                } catch let error as NSError {
                    DispatchQueue.main.async {
                        weakSelf.isRunningBackgroundTask = false
                        completionOnMainThread(.failure(error))
                        weakSelf.unregister(connectionObserver: synchronizedPeripheral)

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
                    weakSelf.register(connectionObserver: synchronizedPeripheral)
                    let result = try backgroundTask(synchronizedPeripheral)

                    DispatchQueue.main.async {
                        weakSelf.isRunningBackgroundTask = false
                        completionOnMainThread(.success(result))
                        weakSelf.unregister(connectionObserver: synchronizedPeripheral)
                    }
                } catch let error as NSError {
                    DispatchQueue.main.async {
                        weakSelf.isRunningBackgroundTask = false
                        completionOnMainThread(.failure(error))
                        weakSelf.unregister(connectionObserver: synchronizedPeripheral)

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
                    weakSelf.register(connectionObserver: synchronizedPeripheral)
                    let result = try backgroundTask(synchronizedPeripheral, userData)

                    DispatchQueue.main.async {
                        weakSelf.isRunningBackgroundTask = false
                        completionOnMainThread(.success(result))
                        weakSelf.unregister(connectionObserver: synchronizedPeripheral)
                    }
                } catch let error as NSError {
                    DispatchQueue.main.async {
                        weakSelf.isRunningBackgroundTask = false
                        completionOnMainThread(.failure(error))
                        weakSelf.unregister(connectionObserver: synchronizedPeripheral)

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

    private func endStartupBackgroundTask() {
        if startupBackgroundTask != UIBackgroundTaskIdentifier.invalid {
            debugLog("Ending startup background task.")
            UIApplication.shared.endBackgroundTask(convertToUIBackgroundTaskIdentifier(startupBackgroundTask.rawValue))
        }

        clearAllRestorationPeripherals()

        isRestoring = false

        // Startup background task should always and only be ended after background restoration is completed.
        debugLog("CoreBluetooth restoration completed.")
    }

    private func clearAllRestorationPeripherals() {
        connectingPeripheralAtRestoration = nil
        disconnectingPeripheralAtRestoration = nil
        disconnectedPeripheralAtRestoration = nil

        debugLog("Cleared all restoration peripheral references.")
    }

    private func clearAllNonRestorationPeripherals() {
        connectingPeripheral = nil
        connectedPeripheral = nil

        debugLog("Cleared all non restoration peripheral references.")
    }

}

// MARK: - CBCentralManagerDelegate

extension Bluejay: CBCentralManagerDelegate {

    /**
     * Routine for restoring to a connecting peripheral.
     *
     * A manual connect attempt is required (Bluejay will do this for you), as CoreBluetooth does not have a connection in-progress, nor does it issue a connect for you even when it is restoring into a connecting state.
     *
     * - Parameter peripheral: the connecting peripheral restored.
     */
    private func restoreConnecting(peripheral: Peripheral) {
        guard let backgroundRestorer = self.backgroundRestorer else {
            fatalError("No background restorer found when restoring a connecting peripheral.")
        }

        connect(peripheral.identifier, timeout: .seconds(15)) { result in
            switch result {
            case .success(let peripheral):
                self.debugLog("Did restore connection to peripheral: \(peripheral.description)")

                let backgroundRestoreCompletion = backgroundRestorer.didRestoreConnection(to: peripheral)

                switch backgroundRestoreCompletion {
                case .callback(let userCallback):
                    userCallback()
                case .continue:
                    break
                }
            case .failure(let error):
                self.debugLog("Did fail to to restore connection with error: \(error.localizedDescription)")

                let backgroundRestoreCompletion = backgroundRestorer.didFailToRestoreConnection(
                    to: peripheral.identifier,
                    error: error
                )

                switch backgroundRestoreCompletion {
                case .callback(let userCallback):
                    userCallback()
                case .continue:
                    break
                }
            }
            self.endStartupBackgroundTask()
        }
    }

    /**
     * Routine for restoring to a connected peripheral.
     *
     * No further connection related actions are required, simply notify the background restorer as well as the connection observers, as interaction with the peripheral is now possible.
     *
     * - Parameter peripheral: the connected peripheral restored.
     */
    private func restoreConnected(peripheral: Peripheral) {
        guard let backgroundRestorer = self.backgroundRestorer else {
            fatalError("No background restorer found when restoring a connected peripheral.")
        }

        debugLog("Did restore connection to peripheral: \(peripheral.identifier.description)")

        let backgroundRestoreCompletion = backgroundRestorer.didRestoreConnection(to: peripheral.identifier)

        switch backgroundRestoreCompletion {
        case .callback(let userCallback):
            userCallback()
        case .continue:
            break
        }

        for observer in connectionObservers {
            observer.weakReference?.connected(to: connectedPeripheral!.identifier)
        }

        endStartupBackgroundTask()
    }

    /**
     * Routine for restoring to a disconnecting peripheral.
     *
     * There is currently no known way to recreate nor to test this scenario. For now, we believe centralManager(_:didDisconnectPeripheral:error:) will not be called in this case, so simply notify failure to restore connection and assume CoreBluetooth will clean up and discard the unused and disconnecting peripheral as long as we don't hold a reference to the disconnecting `CBPeripheral`.
     *
     * - Parameter peripheral: the disconnecting peripheral during state restoration.
     */
    private func restoreDisconnecting(peripheral: Peripheral) {
        guard let backgroundRestorer = self.backgroundRestorer else {
            fatalError("No background restorer found when restoring a disconnecting peripheral.")
        }

        let backgroundRestoreCompletion = backgroundRestorer.didFailToRestoreConnection(
            to: peripheral.identifier,
            error: BluejayError.notConnected
        )

        switch backgroundRestoreCompletion {
        case .callback(let userCallback):
            userCallback()
        case .continue:
            break
        }

        endStartupBackgroundTask()
    }

    /**
     * Routine for restoring to a disconnected peripheral.
     *
     * There is currently no known way to recreate nor to test this scenario. For now, we believe centralManager(_:didDisconnectPeripheral:error:) will not be called in this case, so simply notify failure to restore connection and assume CoreBluetooth will clean up and discard the unused and disconnected peripheral as long as we don't hold a reference to the disconnected `CBPeripheral`.
     *
     * - Parameter peripheral: the disconnected peripheral during state restoration.
     */
    private func restoreDisconnected(peripheral: Peripheral) {
        guard let backgroundRestorer = self.backgroundRestorer else {
            fatalError("No background restorer found when restoring a disconnected peripheral.")
        }

        let backgroundRestoreCompletion = backgroundRestorer.didFailToRestoreConnection(
            to: peripheral.identifier,
            error: BluejayError.notConnected
        )

        switch backgroundRestoreCompletion {
        case .callback(let userCallback):
            userCallback()
        case .continue:
            break
        }

        endStartupBackgroundTask()
    }

    /**
     Bluejay uses this to figure out whether Bluetooth is available or not.

     - If Bluetooth is available for the first time, start running the queue.
     - If Bluetooth is available for the first time and the app is already connected, then this is a state restoration event. Try listen restoration if possible.
     - If Bluetooth is turned off, cancel everything with the `bluetoothUnavailable` error and disconnect.
     - Broadcast state changes to observers.
     */
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        debugLog("Central manager state updated: \(central.state.string())")

        switch central.state {
        case .poweredOn:
            if isRestoring {
                // Clear everything that might be in the queue before completing background restorations.
                cancelEverything(error: BluejayError.backgroundRestorationInProgress, shouldDisconnect: false)

                // Safe to start the queue once it is emptied to allow background restorations, as well as subsequent user requests to complete.
                queue.start()

                if let connectingPeripheralAtRestoration = connectingPeripheralAtRestoration {
                    restoreConnecting(peripheral: connectingPeripheralAtRestoration)
                } else if let connectedPeripheral = connectedPeripheral {
                    restoreConnected(peripheral: connectedPeripheral)
                } else if let disconnectingPeripheralAtRestoration = disconnectingPeripheralAtRestoration {
                    restoreDisconnecting(peripheral: disconnectingPeripheralAtRestoration)
                } else if let disconnectedPeripheralAtRestoration = disconnectedPeripheralAtRestoration {
                    restoreDisconnected(peripheral: disconnectedPeripheralAtRestoration)
                }
            } else {
                // Bluetooth is powered on and ready for Bluejay.
                queue.start()
            }

            for observer in self.connectionObservers {
                observer.weakReference?.bluetoothAvailable(true)
            }
        case .poweredOff, .resetting, .unauthorized, .unknown, .unsupported:
            cancelEverything(error: BluejayError.bluetoothUnavailable)

            clearAllRestorationPeripherals()
            clearAllNonRestorationPeripherals()

            isDisconnecting = false

            for observer in self.connectionObservers {
                observer.weakReference?.bluetoothAvailable(false)
            }
        @unknown default:
            debugLog("New system level CBCentralManager state added.")
        }
    }

    /**
     If Core Bluetooth will restore state, update Bluejay's internal states to match the states of the Core Bluetooth stack by assigning the peripheral to `connectingPeripheral` or `connectedPeripheral`, or niling them out, depending on what the restored `CBPeripheral` state is.
     */
    public func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        debugLog("Central manager will restore state.")

        guard let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral], let cbPeripheral = peripherals.first else {
            debugLog("No peripherals found during state restoration.")
            endStartupBackgroundTask()
            return
        }

        let peripheral = Peripheral(delegate: self, cbPeripheral: cbPeripheral, bluejay: self)
        precondition(peripherals.count == 1, "Invalid number of peripheral to restore.")
        debugLog("Peripheral state to restore: \(cbPeripheral.state.string())")

        isRestoring = true

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
            disconnectingPeripheralAtRestoration = peripheral
        case .disconnected:
            precondition(connectingPeripheral == nil && connectedPeripheral == nil,
                         "Connecting and connected peripherals are not nil during willRestoreState for state: disconnected.")
            disconnectedPeripheralAtRestoration = peripheral
        @unknown default:
            debugLog("New system level CBCentralManager state added.")
        }
    }

    /**
     When connected, update Bluejay's states by updating the values for `connectingPeripheral`, `connectedPeripheral`, and `shouldAutoReconnect`. Also, make sure to broadcast the event to observers, and notify the queue so that the current operation in-flight can process this event and get a chance to finish.
    */
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        debugLog("Central manager did connect to: \(peripheral.name ?? peripheral.identifier.uuidString)")

        connectingCallback = nil

        connectedPeripheral = connectingPeripheral
        connectingPeripheral = nil

        precondition(connectedPeripheral != nil, "Connected peripheral is assigned a nil value despite Bluejay has successfully finished a connection.")

        shouldAutoReconnect = true
        debugLog("Should auto-reconnect: \(shouldAutoReconnect)")

        queue.process(event: .didConnectPeripheral(connectedPeripheral!), error: nil)

        for observer in connectionObservers {
            observer.weakReference?.connected(to: connectedPeripheral!.identifier)
        }
    }

    /**
     Handle a disconnection event from Core Bluetooth by figuring out what kind of disconnection it is (planned or unplanned), and updating Bluejay's internal state and sending notifications as appropriate.
    */
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        // swiftlint:disable:previous cyclomatic_complexity
        let peripheralString = peripheral.name ?? peripheral.identifier.uuidString
        let errorString = error?.localizedDescription

        if let errorMessage = errorString {
            debugLog("Central manager did disconnect from \(peripheralString) with error: \(errorMessage)")
        } else {
            debugLog("Central manager did disconnect from \(peripheralString) without errors.")
        }

        guard let disconnectedPeripheral =
            connectedPeripheral ??
            connectingPeripheral ??
            connectingPeripheralAtRestoration ??
            disconnectingPeripheralAtRestoration ??
            disconnectedPeripheralAtRestoration else {
                debugLog("Central manager disconnected from an unexpected peripheral.")
                return
        }

        let wasRestoringConnectingPeripheral = connectingPeripheralAtRestoration != nil
        let wasRestoringDisconnectingPeripheral = disconnectingPeripheralAtRestoration != nil
        let wasRestoringDisconnectedPeripheral = disconnectedPeripheralAtRestoration != nil
        let wasConnecting = isConnecting
        let wasConnected = isConnected

        if wasRestoringConnectingPeripheral {
            debugLog("Peripheral state was connecting during background restoration before centralManager(_:didDisconnectPeripheral:error:).")
        } else if wasRestoringDisconnectingPeripheral {
            debugLog("Peripheral state was disconnecting during background restoration before centralManager(_:didDisconnectPeripheral:error:).")
        } else if wasRestoringDisconnectedPeripheral {
            debugLog("Peripheral state was disconnected during background restoration before centralManager(_:didDisconnectPeripheral:error:).")
        } else if wasConnecting {
            debugLog("Peripheral was still connecting before centralManager(_:didDisconnectPeripheral:error:).")
        } else if wasConnected {
            debugLog("Peripheral was connected before centralManager(_:didDisconnectPeripheral:error:).")
        }

        clearAllRestorationPeripherals()
        clearAllNonRestorationPeripherals()

        var isExpectedDisconnect = false

        if (!isDisconnecting && !queue.isRunningQueuedDisconnection) || wasRestoringConnectingPeripheral {
            debugLog("The disconnect is unexpected.")

            isExpectedDisconnect = false
            shouldAutoReconnect = !wasRestoringConnectingPeripheral

            debugLog("Should auto-reconnect: \(shouldAutoReconnect)")

            if wasConnected {
                cancelEverything(error: BluejayError.notConnected)
            }
        } else {
            debugLog("The disconnect is expected.")

            isExpectedDisconnect = true
            shouldAutoReconnect = false

            debugLog("Should auto-reconnect: \(shouldAutoReconnect)")
        }

        disconnectCleanUp = { [weak self] in
            guard let weakSelf = self else {
                return
            }

            weakSelf.debugLog("Starting disconnect clean up...")

            var connectingError: Error?

            if wasConnecting || weakSelf.queue.isRunningQueuedDisconnection {
                precondition(
                    !weakSelf.queue.isEmpty,
                    "Queue should not be emptied at the beginning of disconnect clean up when Bluejay was still connecting or has started a queued disconnection."
                )

                if wasConnecting {
                    weakSelf.debugLog("Disconnect clean up: delivering expected disconnected event back to the pending connection in the queue...")

                    if let connection = weakSelf.queue.first as? Connection {
                        if case .running = connection.state {
                            connectingError = BluejayError.unexpectedDisconnect
                        } else if case let .stopping(error) = connection.state {
                            connectingError = error
                        }
                    }

                } else if weakSelf.queue.isRunningQueuedDisconnection {
                    weakSelf.debugLog("Disconnect clean up: delivering expected disconnected event back to the queued disconnection in the queue...")
                }

                // Allow the Connection or Disconnection operation to finish its cancellation, trigger its callback, and continue cancelling any remaining operations in the queue.
                weakSelf.queue.process(event: .didDisconnectPeripheral(disconnectedPeripheral), error: nil)
            } else if wasConnected {
                precondition(weakSelf.queue.isEmpty, "Queue should be emptied before notifying and invoking all disconnect observers and callbacks.")
            }

            if wasRestoringConnectingPeripheral {
                weakSelf.debugLog("Disconnect clean up: disconnected while restoring a connecting peripheral, will not auto-reconnect.")

                guard let connectingError = connectingError else {
                    preconditionFailure(
                        "Missing connecting error at the end of a disconnect clean up after cancelling a connecting peripheral during state restoration."
                    )
                }

                weakSelf.connectingCallback?(.failure(connectingError))
                weakSelf.connectingCallback = nil
            } else {
                weakSelf.debugLog("Disconnect clean up: notifying all connection observers.")

                for observer in weakSelf.connectionObservers {
                    observer.weakReference?.disconnected(from: disconnectedPeripheral.identifier)
                }

                weakSelf.debugLog("Disconnect clean up: should auto-reconnect: \(weakSelf.shouldAutoReconnect)")

                if let disconnectHandler = weakSelf.disconnectHandler {
                    weakSelf.debugLog("Disconnect clean up: calling the disconnect handler.")
                    switch disconnectHandler.didDisconnect(from: disconnectedPeripheral.identifier, with: error, willReconnect: weakSelf.shouldAutoReconnect) {
                    case .noChange:
                        weakSelf.debugLog("Disconnect handler will not change auto-reconnect.")
                    case .change(let autoReconnect):
                        weakSelf.shouldAutoReconnect = autoReconnect
                        weakSelf.debugLog("Disconnect handler changing auto-reconnect to: \(weakSelf.shouldAutoReconnect)")
                    }
                }

                if isExpectedDisconnect {
                    weakSelf.debugLog("Disconnect clean up: calling the explicit disconnect callback if it is provided.")
                    weakSelf.disconnectCallback?(.disconnected(disconnectedPeripheral.identifier))
                    weakSelf.disconnectCallback = nil
                }

                if wasConnecting {
                    guard let connectingError = connectingError else {
                        preconditionFailure("Missing connecting error at the end of a disconnect clean up after cancelling a pending connection.")
                    }

                    weakSelf.debugLog("Disconnect clean up: calling the connecting callback if it is provided.")
                    weakSelf.connectingCallback?(.failure(connectingError))
                    weakSelf.connectingCallback = nil
                }

                weakSelf.isDisconnecting = false

                if weakSelf.shouldAutoReconnect {
                    weakSelf.debugLog("Disconnect clean up: issuing reconnect to: \(peripheral.name ?? peripheral.identifier.uuidString)")
                    weakSelf.connect(
                        PeripheralIdentifier(uuid: peripheral.identifier, name: peripheral.name),
                        timeout: weakSelf.previousConnectionTimeout ?? .none) { _ in }
                }
            }

            weakSelf.debugLog("End of disconnect clean up.")
        }

        if isRunningBackgroundTask {
            debugLog("Delaying disconnect clean up due to running background task.")
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
        connectingPeripheral = Peripheral(delegate: self, cbPeripheral: peripheral, bluejay: self)
    }

}

extension Bluejay: PeripheralDelegate {
    func requested(operation: Operation, from peripheral: Peripheral) {
        queue.add(operation)
    }

    func received(event: Event, error: NSError?, from peripheral: Peripheral) {
        queue.process(event: event, error: error)
    }

    func isReading(characteristic: CharacteristicIdentifier) -> Bool {
        return queue.isReading(characteristic: characteristic)
    }

    func willEndListen(on characteristic: CharacteristicIdentifier) -> Bool {
        return queue.willEndListen(on: characteristic)
    }

    func backgroundRestorationEnabled() -> Bool {
        return isBackgroundRestorationEnabled
    }

    func receivedUnhandledListen(from peripheral: Peripheral, on characteristic: CharacteristicIdentifier, with value: Data?) {
        guard let listenRestorer = listenRestorer else {
            debugLog("Listen restorer not found upon receiving an unhandled listen.")
            return
        }

        let listenRestoreAction = listenRestorer.didReceiveUnhandledListen(from: peripheral.identifier, on: characteristic, with: value)

        switch listenRestoreAction {
        case .promiseRestoration:
            debugLog("Promised restoration for listen on \(characteristic.description) for \(peripheral.identifier.description)")
        case .stopListen:
            debugLog("End listen requested for listen on \(characteristic.description) for \(peripheral.identifier.description)")
            endListen(to: characteristic)
        }
    }

    func didReadRSSI(from peripheral: Peripheral, RSSI: NSNumber, error: Error?) {
        for observer in rssiObservers {
            observer.weakReference?.didReadRSSI(from: peripheral.identifier, RSSI: RSSI, error: error)
        }
    }

    func didModifyServices(from peripheral: Peripheral, invalidatedServices: [ServiceIdentifier]) {
        for observer in serviceObservers {
            observer.weakReference?.didModifyServices(
                from: peripheral.identifier,
                invalidatedServices: invalidatedServices
            )
        }
    }
}

// Helper function inserted by Swift 4.2 migrator.
private func convertToUIBackgroundTaskIdentifier(_ input: Int) -> UIBackgroundTaskIdentifier {
    return UIBackgroundTaskIdentifier(rawValue: input)
}
//swiftlint:disable:this file_length
