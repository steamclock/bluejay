![Bluejay](https://raw.githubusercontent.com/steamclock/bluejay/master/bluejay-wordmark.png)

![CocoaPods Compatible](https://img.shields.io/cocoapods/v/Bluejay.svg)
![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)
[![Platform](https://img.shields.io/cocoapods/p/Bluejay.svg?style=flat)](http://cocoadocs.org/docsets/Bluejay)
[![license](https://img.shields.io/github/license/mashape/apistatus.svg)]()


Bluejay is a simple Swift framework for building reliable Bluetooth LE apps.

Bluejay's primary goals are:
- Simplify talking to a single Bluetooth LE peripheral
- Make it easier to handle Bluetooth operations reliably
- Take advantage of Swift features and conventions

## Index

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Demo](#demo)
- [Usage](#usage)
  - [Initialization](#initialization)
  - [Bluetooth Events](#bluetooth-events)
  - [Services and Characteristics](#services-and-characteristics)
  - [Scanning](#scanning)
  - [Connecting](#connecting)
  - [Disconnect](#disconnect)
  - [Cancel Everything](#cancel-everything)
  - [Auto Reconnect](#auto-reconnect)
  - [Disconnect Handler](#disconnect-handler)
  - [Connection States](#connection-states)
- [Deserialization and Serialization](#deserialization-and-serialization)
  - [Receivable](#receivable)
  - [Sendable](#sendable)
- [Interactions](#interactions)
  - [Reading](#reading)
  - [Writing](#writing)
  - [Listening](#listening)
  - [Background Task](#background-task)
- [Background Restoration](#background-restoration)
  - [Background Permission](#background-permission)
  - [State Restoration](#state-restoration)
  - [Listen Restoration](#listen-restoration)
- [Advanced Usage](#advanced-usage)
  - [Write and Assemble](#write-and-assemble)
  - [Flush Listen](#flush-listen)
  - [CoreBluetooth Migration](#corebluetooth-migration)
  - [Monitor Peripheral Services](#monitor-peripheral-services)

## Features

- A callback-based API
- A FIFO operation queue for more synchronous and predictable behaviour
- A background task mode for batch operations that avoids the "callback pyramid of death"
- Simple protocols for data serialization and deserialization
- An easy and safe way to observe connection states
- Powerful background restoration support
- Extended error handling and logging support

## Requirements

- iOS 11 or later recommended
- Xcode 11.3.1 or later recommended
- Swift 5 or later recommended

## Installation

### CocoaPods

`pod 'Bluejay', '~> 0.8'`

Or to try the latest master:

`pod 'Bluejay', :git => 'https://github.com/steamclock/bluejay.git', :branch => 'master'`

### Carthage

```
github "steamclock/bluejay" ~> 0.8
github "DaveWoodCom/XCGLogger" ~> 6.1.0
```

Refer to [official Carthage documentation](https://github.com/Carthage/Carthage#supporting-carthage-for-your-framework) for the rest of the instructions.

**Note:** `Bluejay.framework`, `ObjcExceptionBridging.framework`, and `XCGLogger.framework` are all required.

### Import

```swift
import Bluejay
```

## Demo

The iOS Simulator does not simulate Bluetooth, and you may not have a debuggable Bluetooth LE peripheral handy, so we have prepared you a pair of demo apps to test with.

1. **BluejayHeartSensorDemo:** an app that can connect to a Bluetooth LE heart sensor.
2. **DittojayHeartSensorDemo:** a virtual Bluetooth LE heart sensor.

#### To try out Bluejay:

1. Get two iOS devices – one to run **Bluejay Demo**, and the other to run **Dittojay Demo**.
2. Grant permission for notifications on **Bluejay Demo**.
3. Grant permission for background mode on **Dittojay Demo**.
4. Connect using **Bluejay Demo**.

#### To try out background restoration (after connecting):

1. In **Bluejay Demo**, tap on "End listen to heart rate".
- This is to prevent the continuous heart rate notification from triggering state restoration right after we terminate the app, as it's much clearer and easier to verify state restoration when we can manually trigger a Bluetooth event at our own leisure and timing.
2. Tap on "Terminate app".
- This will crash the app, but also simulate app termination due to memory pressure, **and** allow CoreBluetooth to cache the current session and wait for Bluetooth events to begin state restoration.
3. In **Dittojay Demo**, tap on "Chirp" to *revive* **Bluejay Demo**
- This will send a Bluetooth event to the device with the terminated **Bluejay Demo**, and its CoreBluetooth stack will wake up the app in the background and execute a few quick tasks, such as scheduling a few local notifications for verification and debugging purposes in this case.

## Usage

### Initialization

To create an instance of Bluejay:

```swift
let bluejay = Bluejay()
```

While it is convenient to create one Bluejay instance and use it everywhere, you can also create instances in specific portions of your app and tear them down after use. It's worth noting, however, that each instance of Bluejay has its own [CBCentralManager](https://developer.apple.com/documentation/corebluetooth/cbcentralmanager), which makes the multi-instance approach somewhat more complex.

Once you've created an instance, you can start running Bluejay, which will then initialize the [CoreBluetooth](https://developer.apple.com/documentation/corebluetooth) session. Note that **instantiating a Bluejay instance and running a Bluejay instance are two separate operations.**

You must always start Bluejay in your AppDelegate's `application(_:didFinishLaunchingWithOptions:)` if you want to support [background restoration](#background-restoration), otherwise you are free to start Bluejay anywhere appropriate in your app. For example, apps that don't require background restoration often initialize and start their Bluejay instance from the initial view controller.

```swift
bluejay.start()
```

If your app needs Bluetooth to work in the background, then you have to support background restoration in your app. While Bluejay has already simplified much of background restoration for you, [it will still take some extra work](#background-restoration), and we also recommend reviewing the [relevant Apple docs](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html). Background restoration is tricky and difficult to get right.

Bluejay also supports [CoreBluetooth migration](#corebluetooth-migration) for working with other Bluetooth libraries or with your own Bluetooth code.

### Bluetooth Events

The `ConnectionObserver` protocol allows a class to monitor and to respond to major Bluetooth and connection-related events:

```swift
public protocol ConnectionObserver: class {
    func bluetoothAvailable(_ available: Bool)
    func connected(to peripheral: PeripheralIdentifier)
    func disconnected(from peripheral: PeripheralIdentifier)
}
```

You can register a connection observer using:

```swift
bluejay.register(connectionObserver: batteryLabel)
```

Unregistering a connection observer is not necessary, because Bluejay only holds weak references to registered observers, so Bluejay will clear nil observers from its list when they are found at the next event's firing. But if you need to do so before that happens, you can use:

```swift
bluejay.unregister(connectionObserver: rssiLabel)
```

### Services and Characteristics

In Bluetooth parlance, a Service is a group of attributes, and a Characteristic is an attribute belonging to a group. For example, BLE peripherals that can detect heart rates typically have a Service named "Heart Rate" with a UUID of "180D". Inside that Service are Characteristics such as "Body Sensor Location" with a UUID of "2A38", as well as "Heart Rate Measurement" with a UUID of "2A37".

Many of these Services and Characteristics are standards specified by the Bluetooth SIG organization, and most hardware adopt their specifications. For example, most BLE peripherals implement the Service "Device Information" which has a UUID of "180A", which is where Characteristics such as firmware version, serial number, and other hardware details can be found. Of course, there are many BLE uses not covered by the Bluetooth Core Spec, and custom hardware often have their own unique Services and Characteristics.

Here is how you can specify Services and Characteristics for use in Bluejay:

```swift
let heartRateService = ServiceIdentifier(uuid: "180D")
let bodySensorLocation = CharacteristicIdentifier(uuid: "2A38", service: heartRateService)
let heartRate = CharacteristicIdentifier(uuid: "2A37", service: heartRateService)
```

Bluejay uses the `ServiceIdentifier` and `CharacteristicIdentifier` structs to avoid problems like accidentally specifying a Service when a Characteristic is expected.

### Scanning

Bluejay has a powerful scanning API that can be be used simply or customized to satisfy many use cases.

CoreBluetooth scans for devices using services. In other words, CoreBluetooth, and therefore Bluejay, expects you to know beforehand one or several public services the peripherals you want to scan for contains.

#### Basic Scanning

This simple call will just notify you when there is a new discovery, and when the scan has finished:

```swift
bluejay.scan(
    serviceIdentifiers: [heartRateService],
    discovery: { [weak self] (discovery, discoveries) -> ScanAction in
        guard let weakSelf = self else {
            return .stop
        }

        weakSelf.discoveries = discoveries
        weakSelf.tableView.reloadData()

        return .continue
    },
    stopped: { (discoveries, error) in
        if let error = error {
            debugPrint("Scan stopped with error: \(error.localizedDescription)")
        }
        else {
            debugPrint("Scan stopped without error.")
        }
})
```

A scan result `(ScanDiscovery, [ScanDiscovery])` contains the current discovery followed by an array of all the discoveries made so far.

The stopped result contains a final list of discoveries available just before stopping, and an error if there is one. If there isn't an error, that means that the scan was stopped intentionally or expectedly.

#### Scan Action

A `ScanAction` is returned at the end of a discovery callback to tell Bluejay whether to keep scanning or to stop.

```swift
public enum ScanAction {
    case `continue`
    case blacklist
    case stop
    case connect(ScanDiscovery, (ConnectionResult) -> Void)
}
```

Returning `blacklist` will ignore any future discovery of the same peripheral within the current scan session. This is only useful when `allowDuplicates` is set to true. See [Apple docs on CBCentralManagerScanOptionAllowDuplicatesKey](https://developer.apple.com/documentation/corebluetooth/cbcentralmanagerscanoptionallowduplicateskey?language=objc) for more info.

Returning `connect` will make Bluejay stop the scan as well as perform your connection request. This is useful if you want to connect right away when you've found the peripheral you're looking for.

**Tip:** You can set up the `ConnectionResult` block outside the scan call to reduce callback nesting.

#### Monitoring

Another useful way to use the scanning API is to scan continuously, i.e. to monitor, for purposes such as observing the RSSI changes of nearby peripherals to estimate their proximity:

```swift
bluejay.scan(
    duration: 15,
    allowDuplicates: true,
    serviceIdentifiers: nil,
    discovery: { [weak self] (discovery, discoveries) -> ScanAction in
        guard let weakSelf = self else {
            return .stop
        }

        weakSelf.discoveries = discoveries
        weakSelf.tableView.reloadData()

        return .continue
    },
    expired: { [weak self] (lostDiscovery, discoveries) -> ScanAction in
        guard let weakSelf = self else {
            return .stop
        }

        debugPrint("Lost discovery: \(lostDiscovery)")

        weakSelf.discoveries = discoveries
        weakSelf.tableView.reloadData()

        return .continue
}) { (discoveries, error) in
        if let error = error {
            debugPrint("Scan stopped with error: \(error.localizedDescription)")
        }
        else {
            debugPrint("Scan stopped without error.")
        }
}
```

Setting `allowDuplicates` to true will stop coalescing multiple discoveries of the same peripheral into one single discovery callback. Instead, you'll get a discovery call every time a peripheral's advertising packet is picked up. This will **consume more battery, and does not work in the background**.

**Warning:** An allow duplicates scan will stop with an error if your app is backgrounded during the scan.

The `expired` callback is only invoked when `allowDuplicates` is true. This is called when Bluejay estimates that a previously discovered peripheral is likely out of range or no longer broadcasting. Essentially, when `allowDuplicates` is set to true, every time a peripheral is discovered a timer associated with that peripheral starts counting down. If that peripheral is within range, and even if it has a slow broadcasting interval, it is likely that peripheral will be picked up by the scan again and cause the timer to refresh. If not and the timer expires without being refreshed, Bluejay makes an educated guess and suggests that the peripheral is no longer reachable. Be aware that this is an estimation.

**Warning**: Setting `serviceIdentifiers` to `nil` will result in picking up all available Bluetooth peripherals in the vicinity, **but is not recommended by Apple**. It may cause **battery and cpu issues** on prolonged scanning, and it also **doesn't work in the background**. It is not a private API call, but an available option where you need a quick solution when testing and prototyping.

**Tip:** Specifying at least one specific service identifier is the most common way to scan for Bluetooth devices in iOS. If you need to scan for all Bluetooth devices, we recommend making use of the `duration` parameter to stop the scan after 5 ~ 10 seconds to avoid scanning indefinitely and overloading the hardware.

### Connecting

It is important to keep in mind that Bluejay is designed to work with a single BLE peripheral. Multiple connections at once is not currently supported, and a connection request will fail if Bluejay is already connected or is still connecting. Although this can be a limitation for some sophisticated apps, it is more commonly a safeguard to ensure your app does not issue connections unnecessarily or erroneously.

```swift
bluejay.connect(selectedSensor, timeout: .seconds(15)) { result in
    switch result {
    case .success:
        debugPrint("Connection attempt to: \(selectedSensor.description) is successful")
    case .failure(let error):
        debugPrint("Failed to connect with error: \(error.localizedDescription)")
    }
}
```

#### Timeouts

You can also specify a timeout for a connection request, default is no timeout:

```swift
public enum Timeout {
    case seconds(TimeInterval)
    case none
}
```

**Tip:** We recommend always setting at least a 15 seconds timeout for your connection requests.

### Disconnect

To disconnect:

```swift
bluejay.disconnect()
```

Bluejay also supports finer controls over your disconnection:

#### Queued Disconnect

A queued disconnect will be queued like all other Bluejay API requests, so the disconnect attempt will wait for its turn until all the queued tasks are finished.

To perform a queued disconnect, simply call:

```swift
bluejay.disconnect()
```

#### Immediate Disconnect

An immediate disconnect will immediately fail and empty all tasks from the queue even if they are still running and then immediately disconnect.

There are two ways to perform an immediate disconnect:

```swift
bluejay.disconnect(immediate: true)
```

```swift
bluejay.cancelEverything()
```

#### Expected vs Unexpected Disconnection

Bluejay's log will describe in detail whether a disconnection is expected or unexpected. This is important when debugging a disconnect-related issue, as well as explaining why Bluejay is or isn't attempting to auto reconnect.

Any explicit call to `disconnect` or `cancelEverything` with disconnect will result in an expected disconnection.

All other disconnection events will be considered unexpected. For examples:
- If a connection attempt fails due to hardware errors and not from a timeout
- If a connected device moves out of range
- If a connected device runs out of battery or is shut off
- If a connected device's Bluetooth module crashes and is no longer negotiable

### Cancel Everything

The reason why there is a `cancelEverything` API in addition to `disconnect`, is because sometimes we want to cancel everything in the queue but **remain** connected.

```swift
bluejay.cancelEverything(shouldDisconnect: false)
```

### Auto Reconnect

By default, `shouldAutoReconnect` is `true` and Bluejay will always try to automatically reconnect after an unexpected disconnection.

Bluejay will only set `shouldAutoReconnect` to `false` under these circumstances:

1. If you manually call `disconnect` and the disconnection is successful.
2. If you manually call `cancelEverything` and its disconnection is successful.

Bluejay will also **always** reset `shouldAutoReconnect` to `true` on a successful connection to a peripheral, as we usually want to reconnect to the same device as soon as possible if a connection is lost unexpectedly during normal usage.

However, there are some cases where auto reconnect is not desirable. In those cases, use a `DisconnectHandler` to evaluate and to override auto reconnect.

### Disconnect Handler

A disconnect handler is a single delegate that is suitable for performing major recovery, retry, or reset operations, such as restarting a scan when there is a disconnection.

The purpose of this handler is to help avoid writing and repeating major resuscitation and error handling logic inside the error callbacks of your regular connect, disconnect, read, write, and listen calls. Use the disconnect handler to perform one-time and significant operations at the very end of a disconnection.

In addition to helping you avoid redundant and conflicted logic in various callbacks when there is a disconnection, the disconnect handler also allows you to evaluate and to control Bluejay's auto-reconnect behaviour.

For example, this protocol implementation will always turn off auto reconnect whenever there is a disconnection, expected or not.

```swift
func didDisconnect(
  from peripheral: PeripheralIdentifier,
  with error: Error?,
  willReconnect autoReconnect: Bool) -> AutoReconnectMode {
    return .change(shouldAutoReconnect: false)
}
```

We also anticipate that for most apps, different view controllers may want to handle disconnection differently, so simply register and replace the existing disconnect handler as your user navigates to different parts of your app.

```swift
bluejay.registerDisconnectHandler(handler: self)
```

Similar to connection observers, you do not have to explicitly unregister unless you need to.

### Connection States

Your Bluejay instance has these properties to help you make connection-related decisions:

- `isBluetoothAvailable`
- `isBluetoothStateUpdateImminent`
- `isConnecting`
- `isConnected`
- `isDisconnecting`
- `shouldAutoReconnect`
- `isScanning`
- `hasStarted`
- `defaultWarningOptions`
- `isBackgroundRestorationEnabled`

## Deserialization and Serialization

Reading, writing, and listening to Characteristics is straightforward in Bluejay. Most of the work involved is building out the deserialization and serialization for your data. Let's have a quick look at how Bluejay helps standardize this process in your app via the `Receivable` and `Sendable` protocols.

#### Receivable

Models that represent data you wish to read and receive from your peripheral should all conform to the `Receivable` protocol.

Here is a partial example for the [Heart Rate Measurement Characteristic](https://www.bluetooth.com/specifications/gatt/viewer?attributeXmlFile=org.bluetooth.characteristic.heart_rate_measurement.xml):

```swift
import Bluejay
import Foundation

struct HeartRateMeasurement: Receivable {

    private var flags: UInt8 = 0
    private var measurement8bits: UInt8 = 0
    private var measurement16bits: UInt16 = 0
    private var energyExpended: UInt16 = 0
    private var rrInterval: UInt16 = 0

    private var isMeasurementIn8bits = true

    var measurement: Int {
        return isMeasurementIn8bits ? Int(measurement8bits) : Int(measurement16bits)
    }

    init(bluetoothData: Data) throws {
        flags = try bluetoothData.extract(start: 0, length: 1)

        isMeasurementIn8bits = (flags & 0b00000001) == 0b00000000

        if isMeasurementIn8bits {
            measurement8bits = try bluetoothData.extract(start: 1, length: 1)
        } else {
            measurement16bits = try bluetoothData.extract(start: 1, length: 2)
        }
    }

}

```

Note how you can use the `extract` function that Bluejay adds to `Data` to easily parse the bytes you need. We have plans to build more protection and error handling for this in the future.

Finally, while it is not essential and it will depend on the context, we suggest only exposing the needed and computed properties of your models.

#### Sendable

Models representing data you wish to send to your peripheral should all conform to the `Sendable` protocol. In a nutshell, this is how you help Bluejay determine how to convert your models into `Data`:

```swift
import Foundation
import Bluejay

struct Coffee: Sendable {

    let data: UInt8

    init(coffee: CoffeeEnum) {
        data = UInt8(coffee.rawValue)
    }

    func toBluetoothData() -> Data {
        return Bluejay.combine(sendables: [data])
    }

}
```

The `combine` helper function makes it easier to group and to sequence the outgoing data.

#### Sending and Receiving Primitives

In some cases, you may want to send or receive data simple enough that creating a custom struct which implements `Sendable` or `Receivable` to hold it is unnecessarily complicated. For those cases, Bluejay also retroactively conforms several built-in Swift types to `Sendable` and `Receivable`. `Int8`, `Int16`, `Int32`, `Int64`, `UInt8`, `UInt16`, `UInt32`, `UInt64`, `Data` are all conformed to both protocols and so they can all be sent or received directly.

`Int` and `UInt` are intentionally not conformed. Bluetooth values are always sent and/or received at a specific bit width. The intended bit width for an `Int` is ambiguous, and trying to use one often indicates a programmer error, in the form of not considering the bit width the Bluetooth device is expecting on a characteristic.

## Interactions

Once you have your data modelled using either the `Receivable` or `Sendable` protocol, the read, write, and listen APIs in Bluejay should handle the deserialization and serialization seamlessly for you. All you need to do is to specify the type for the generic result wrappers: `ReadResult<T>` or `WriteResult<T>`.

### Reading

Here is an example showing how to read the [sensor body location characteristic](https://www.bluetooth.com/specifications/gatt/viewer?attributeXmlFile=org.bluetooth.characteristic.body_sensor_location.xml), and converting its value to its corresponding string and display it in the UI.

```swift
let heartRateService = ServiceIdentifier(uuid: "180D")
let sensorLocation = CharacteristicIdentifier(uuid: "2A38", service: heartRateService)

bluejay.read(from: sensorLocation) { [weak self] (result: ReadResult<UInt8>) in
    guard let weakSelf = self else {
	     return
    }

    switch result {
    case .success(let location):
        debugPrint("Read from sensor location is successful: \(location)")

        var locationString = "Unknown"

        switch location {
        case 0:
            locationString = "Other"
        case 1:
            locationString = "Chest"
        case 2:
            locationString = "Wrist"
        case 3:
            locationString = "Finger"
        case 4:
            locationString = "Hand"
        case 5:
            locationString = "Ear Lobe"
        case 6:
            locationString = "Foot"
        default:
            locationString = "Unknown"
        }

        weakSelf.sensorLocationCell.detailTextLabel?.text = locationString
    case .failure(let error):
        debugPrint("Failed to read sensor location with error: \(error.localizedDescription)")
    }
}
```

### Writing

Writing to a characteristic is very similar to reading:

```swift
let heartRateService = ServiceIdentifier(uuid: "180D")
let sensorLocation = CharacteristicIdentifier(uuid: "2A38", service: heartRateService)

bluejay.write(to: sensorLocation, value: UInt8(2)) { result in
    switch result {
    case .success:
        debugPrint("Write to sensor location is successful.")
    case .failure(let error):
        debugPrint("Failed to write sensor location with error: \(error.localizedDescription)")
    }
}
```

### Listening

Listening turns on broadcasting on a characteristic and allows you to receive its notifications.

Unlike read and write where the completion block is only called once, listen callbacks are persistent. It could be minutes (or never) before the receive block is called, and the block can be called multiple times.

Some Bluetooth devices will turn off notifications when it is disconnected, some don't. That said, when you don't need to listen anymore, it is generally good practice to always explicitly turn off broadcasting on that characteristic using the `endListen` function.

Not all characteristics support listening, it is a feature that must be enabled for a characteristic on the Bluetooth device itself.

```swift
let heartRateService = ServiceIdentifier(uuid: "180D")
let heartRateCharacteristic = CharacteristicIdentifier(uuid: "2A37", service: heartRateService)

bluejay.listen(to: heartRateCharacteristic, multipleListenOption: .replaceable)
{ [weak self] (result: ReadResult<HeartRateMeasurement>) in
        guard let weakSelf = self else {
            return
        }

        switch result {
        case .success(let heartRate):
            weakSelf.heartRate = heartRate
            weakSelf.tableView.reloadData()
        case .failure(let error):
            debugPrint("Failed to listen with error: \(error.localizedDescription)")
        }
}
```

#### Multiple Listen Options

You can only have one listener callback installed per characteristic. If you need multiple observers on the same characteristic, you can still do so yourself using just one Bluejay listener and within it create your own app-specific notifications.

Pass in the appropriate `MultipleListenOption` in your listen call to either protect against multiple listen attempts on the same characteristic, or to intentionally allow overwriting an existing listen.

```swift
/// Ways to handle calling listen on the same characteristic multiple times.
public enum MultipleListenOption: Int {
    /// New listen on the same characteristic will not overwrite an existing listen.
    case trap
    /// New listens on the same characteristic will replace the existing listen.
    case replaceable
}
```

### Background Task

Bluejay also supports performing a longer series of reads, writes, and listens in a background thread. Each operation in a background task is blocking and will not return until completed.

This is useful when you need to complete a specific and large task such as syncing or upgrading to a new firmware. This is also useful when working with a notification-based Bluetooth module where you need to pause and wait for Bluetooth execution, primarily the listen operation, but without blocking the main thread.

Bluejay will call your completion block on the main thread when everything finishes without an error, or if any one of the operations in the background task has failed.

Here's a made-up example in trying get both user and admin access to a Bluetooth device using the same password:

```swift
var isUserAuthenticated = false
var isAdminAuthenticated = false

bluejay.run(backgroundTask: { (peripheral) -> (Bool, Bool) in
    // 1. No need to perform any Bluetooth tasks if there's no password to try.
    guard let password = enteredPassword else {
      return (false, false)
    }

    // 2. Flush auth characteristics in case they are still broadcasting unwanted data.
    try peripheral.flushListen(to: userAuth, nonZeroTimeout: .seconds(3), completion: {
        debugPrint("Flushed buffered data on the user auth characteristic.")
    })

    try peripheral.flushListen(to: adminAuth, nonZeroTimeout: .seconds(3), completion: {
        debugPrint("Flushed buffered data on the admin auth characteristic.")
    })

    // 3. Sanity checks, making sure the characteristics are not broadcasting anymore.
    try peripheral.endListen(to: userAuth)
    try peripheral.endListen(to: adminAuth)

    // 4. Attempt authentication.
    if let passwordData = password.data(using: .utf8) {
        debugPrint("Begin authentication...")

        try peripheral.writeAndListen(
            writeTo: userAuth,
            value: passwordData,
            listenTo: userAuth,
            timeoutInSeconds: .seconds(15),
            completion: { (response: UInt8) -> ListenAction in
                if let responseCode = AuthResponse(rawValue: response) {
                    isUserAuthenticated = responseCode == .success
                }

                return .done
        })

        try peripheral.writeAndListen(
            writeTo: adminAuth,
            value: passwordData,
            listenTo: adminAuth,
            timeoutInSeconds: .seconds(15),
            completion: { (response: UInt8) -> ListenAction in
                if let responseCode = AuthResponse(rawValue: response) {
                    isAdminAuthenticated = responseCode == .success
                }

                return .done
        })
    }

    // 5. Return results of authentication.
    return (isUserAuthenticated, isAdminAuthenticated)
}, completionOnMainThread: { (result) in
    switch result {
    case .success(let authResults):
        debugPrint("Is user authenticated: \(authResults.0)")
        debugPrint("Is admin authenticated: \(authResults.1)")
    case .failure(let error):
        debugPrint("Background task failed with error: \(error.localizedDescription)")
    }
})
```

**Important:**

While Bluejay will not crash because it has built in error handling that will inform you of the following violations, these rules are are still worth calling out:

1. **Do not** call any regular `read/write/listen` functions inside the `backgroundTask` block. Use the `SynchronizedPeripheral` provided to you and its `read/write/listen` API instead.
2. Regular `read/write/listen` calls outside of the `backgroundTask` block will **also not work** when a background task is still running.

Note that because the `backgroundTask` block is running on a background thread, you need to be careful about accessing any global or captured data inside that block for thread safety reasons, like you would with any GCD or OperationQueue task. To help with this, use `run(userData:backgroundTask:completionOnMainThread:)` to pass an object you wish to have thread-safe access to while working inside the background task.

## Background Restoration

[CoreBluetooth allows apps to continue processing active Bluetooth operations when it is backgrounded or even when it is evicted from memory](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html). In Bluejay, we refer to this feature and behaviour as "background restoration". For examples, a pending connect request that finishes, or a subscribed characteristic that fires a notification, can cause the system to wake or restart the app in the background. This can, for example, allow syncing data from a device without requiring the user to launch the app.

In order to support background Bluetooth, there are two steps to take:
1. Give your app permission to use Bluetooth in the background
2. Implement and handle state restoration

### Background Permission

This is the easy step. Just turn on the **Background Modes** capability in your Xcode project with **Uses Bluetooth LE accessories** enabled.

### State Restoration

Bluejay already handles much of the gnarly state restoration implementation for you. However, there are still a few things you need to do to help Bluejay help you:

1. Create a background restoration configuration with a restore identifier
2. Always start your Bluejay instance in your AppDelegate's `application(_:didFinishLaunchingWithOptions:)`
3. Always pass Bluejay the `launchOptions`
4. Setup a `BackgroundRestorer` and a `ListenRestorer` to handle restoration results

```swift
import Bluejay
import UIKit

let bluejay = Bluejay()

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        let backgroundRestoreConfig = BackgroundRestoreConfig(
            restoreIdentifier: "com.steamclock.bluejayHeartSensorDemo",
            backgroundRestorer: self,
            listenRestorer: self,
            launchOptions: launchOptions)

        let backgroundRestoreMode = BackgroundRestoreMode.enable(backgroundRestoreConfig)

        let options = StartOptions(
          enableBluetoothAlert: true,
          backgroundRestore: backgroundRestoreMode)

        bluejay.start(mode: .new(options))

        return true
    }

}

extension AppDelegate: BackgroundRestorer {
    func didRestoreConnection(
      to peripheral: PeripheralIdentifier) -> BackgroundRestoreCompletion {
        // Opportunity to perform syncing related logic here.
        return .continue
    }

    func didFailToRestoreConnection(
      to peripheral: PeripheralIdentifier, error: Error) -> BackgroundRestoreCompletion {
        // Opportunity to perform cleanup or error handling logic here.
        return .continue
    }
}

extension AppDelegate: ListenRestorer {
    func didReceiveUnhandledListen(
      from peripheral: PeripheralIdentifier,
      on characteristic: CharacteristicIdentifier,
      with value: Data?) -> ListenRestoreAction {
        // Re-install or defer installing a callback to a notifying characteristic.
        return .promiseRestoration
    }
}
```

While Bluejay has simplified background restoration to just a few initialization rules and two protocols, it can still be difficult to get right. Please contact us if you have any questions

### Listen Restoration

If you app is evicted from memory, you lose all your listen callbacks as well. Yet, the Bluetooth device can still be broadcasting on the characteristics you were listening to. Listen restoration gives you an opportunity to restore and to respond to that notification when your app is restored in the background.

If you need to re-install a listen, simply call `listen` again as you normally would when setting up a new listen inside `didReceiveUnhandledListen(from:on:with:)` before returning `.promiseRestoration`. Otherwise, return `.stopListen` to ask Bluejay to turn off notification on that characteristic.

```swift
/**
 * Available actions to take on an unhandled listen event from background restoration.
 */
public enum ListenRestoreAction {
    /// Bluejay will continue to receive but do nothing with the incoming listen events until a new listener is installed.
    case promiseRestoration
    /// Bluejay will attempt to turn off notifications on the peripheral.
    case stopListen
}
```

```swift
extension AppDelegate: ListenRestorer {
    func didReceiveUnhandledListen(
      from peripheral: PeripheralIdentifier,
      on characteristic: CharacteristicIdentifier,
      with value: Data?) -> ListenRestoreAction {
        // Re-install or defer installing a callback to a notifying characteristic.
        return .promiseRestoration
    }
}
```

## Advanced Usage

The following section will demonstrate a few advanced usage of Bluejay.

### Write and Assemble

One of the Bluetooth modules we've worked with doesn't always send back the entire data in one packet, even if the data is smaller than either the software's or hardware's maximum packet size. To handle incoming data that can be broken up into an unknown number of packets, we've added the `writeAndAssemble` function that is very similar to `writeAndListen` on the `SynchronizedPeripheral`. Therefore, at least for now, this is currently only supported when using the [background task](#background-task).

When using `writeAndAssemble`, we still expect you to know the total size of the data you are receiving, but Bluejay will keep listening and receiving packets until the expected size is reached before trying to [deserialize](#deserialization-and-serialization) the data into the object you need.

You can also specify a timeout in case something hangs or takes abnormally long.

Here is an example writing a request for a value to a Bluetooth module, so that it can return the value we want via a notification on a characteristic. And of course, we're not sure and have no control over how many packets the module will send back.

```swift
try peripheral.writeAndAssemble(
    writeTo: Characteristics.rigadoTX,
    value: ReadRequest(handle: Registers.system.firmwareVersion),
    listenTo: Characteristics.rigadoRX,
    expectedLength: FirmwareVersion.length,
    completion: { (firmwareVersion: FirmwareVersion) -> ListenAction in
        settings.firmware = firmwareVersion.string
        return .done
})
```

### Flush Listen

Some Bluetooth modules will pause sending data when it loses connection to your app, then resume sending the same set of data from where it left off when the connection is re-established. This isn't an issue most of the time, except for Bluetooth modules that do overload one characteristic with multiple purposes and values.

For example, you might have to re-authenticate the user when the app is re-opened. But if authentication requires listening to the same characteristic where an incomplete data set from a previous request is still being sent, then you will be getting back unexpected values and most likely crash when trying to [deserialize](#deserialization-and-serialization) authentication related objects.

To handle this, it is often a good idea to flush a notifiable characteristic before starting a critical operation. This is also only available on the `SynchronizedPeripheral` when working within the [background task](#background-task)

```swift
try peripheral.flushListen(to: auth, nonZeroTimeout: .seconds(3), completion: {
    debugPrint("Flushed buffered data on the auth characteristic.")
})
```

The `nonZeroTimeout` specifies the duration of the **absence of incoming data** needed to predict that the flush is most likely completed. In the above example, it is not that the flush will come to a hard stop after 3 seconds, but rather will only stop if Bluejay doesn't have any data to flush after waiting for 3 seconds. It will continue to flush for as long as there is incoming data.

### CoreBluetooth Migration

If you want to start Bluejay with a pre-existing CoreBluetooth stack, you can do so by specifying `.use` in the start mode instead of `.new` when calling the `start` function.

```swift
bluejay.start(mode: .use(manager: anotherManager, peripheral: alreadyConnectedPeripheral))
```

You can also transfer Bluejay's CoreBluetooth stack to another Bluetooth library or your own using this function:

```swift
public func stopAndExtractBluetoothState() ->
    (manager: CBCentralManager, peripheral: CBPeripheral?)
```

Finally, you can check whether Bluejay has been started or stopped using the `hasStarted` property.

### Monitor Peripheral Services

Some peripherals can add or remove services while it's being used, and Bluejay provides a basic way to react to this. See **BluejayHeartSensorDemo** and **DittojayHeartSensorDemo** in the project for more examples.

```swift
bluejay.register(serviceObserver: self)
```

```swift
func didModifyServices(
  from peripheral: PeripheralIdentifier,
  invalidatedServices: [ServiceIdentifier]) {
    if invalidatedServices.contains(where: { invalidatedServiceIdentifier -> Bool in
        invalidatedServiceIdentifier == chirpCharacteristic.service
    }) {
        endListen(to: chirpCharacteristic)
    } else if invalidatedServices.isEmpty {
        listen(to: chirpCharacteristic)
    }
}
```

**Notes from Apple:**

> If you previously discovered any of the services that have changed, they are provided in the invalidatedServices parameter and can no longer be used. You can use the discoverServices: method to discover any new services that have been added to the peripheral’s database or to find out whether any of the invalidated services that you were using (and want to continue using) have been added back to a different location in the peripheral’s database.

## API Documentation

We have more [in-depth API documentation for Bluejay](https://steamclock.github.io/bluejay/index.html) using inline documentation and Jazzy.
