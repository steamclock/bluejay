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
  - [Timeouts](#timeouts)
  - [Connection States](#connection-states)
- [Deserialization and Serialization](#deserialization-and-serialization)
  - [Receivable](#receivable)
  - [Sendable](#sendable)
- [Interactions](#interactions)
  - [Reading](#reading)
  - [Writing](#writing)
  - [Listening](#listening)
  - [Batch Operations](#batch-operations)
- [Background Operation](#background-operation)
  - [State Restoration](#state-restoration)
  - [Listen Restoration](#listen-restoration)
- [Advanced Usage](#advanced-usage)
  - [Connect by Serial Number](#connect-by-serial-number)
  - [Write and Assemble](#write-and-assemble)
  - [Flush Listen](#flush-listen)
  - [CoreBluetooth Migration](#corebluetooth-migration)

## Features

- A callback-based API
- A FIFO operation queue for more synchronous and predictable behaviour
- A background task mode for batch operations that avoids the "callback pyramid of death"
- Simple protocols for data serialization and deserialization
- An easy and safe way to observe connection states
- Listen restoration
- Extended error handling

## Requirements

- iOS 9.3 or above
- Xcode 8.2.1 or above
- Swift 3.2 or above

## Installation

Install using CocoaPods:

`pod 'Bluejay', '~> 0.7'`

Or to try the latest master:

`pod 'Bluejay', :git => 'https://github.com/steamclock/bluejay.git', :branch => 'master'`

Cartfile:

`github "steamclock/bluejay" ~> 0.7`

Import using:

```swift
import Bluejay
```

## Demo

The iOS Simulator does not simulate Bluetooth. You may not have a debuggable Bluetooth LE peripheral handy, so we recommend trying Bluejay using a BLE peripheral simulator such as the [LightBlue Explorer App](https://itunes.apple.com/ca/app/lightblue-explorer-bluetooth/id557428110?mt=8).

Bluejay has a demo app called **BluejayDemo** that works with LightBlue Explorer. To see it in action:

1. Get two iOS devices – one to run a BLE peripheral simulator, and the other to run the Bluejay demo app.
2. On one iOS device, go to the App Store and download LightBlue Explorer.
3. Launch LightBlue Explorer, and tap on the **Create Virtual Peripheral** button located at the bottom of the peripheral list.
4. To start, choose **Heart Rate** from the base profile list, and finish by tapping the **Save** button.
5. Finally, build and run **BluejayDemo** on the other iOS device. Once it launches, choose **Heart Rate Sensor** in the menu, and you will be able to start interacting with the virtual heart rate peripheral.

**Notes:**

- You can turn the virtual peripheral on or off in LightBlue Explorer by tapping the blue circle to the left of the peripheral's name.
	- If the virtual peripheral is not working as expected, you can try to reset it this way.
- The virtual peripheral may use your iPhone or iPad name, because the virtual peripheral is an extension of the host device.
- Some characteristics in the various virtual peripherals available in LightBlue Explorer might not have read of write permissions enabled by default, but you can change most of those settings.
	- After selecting your virtual peripheral, tap on the characteristic you wish to modify, then tap on either the "Read" or "Write" property to customize their permissions.
	- Characteristics belonging to the Device Information service, for example, are read only.

## Usage

### Initialization

Create an instance of Bluejay:

```swift
let bluejay = Bluejay()
```

While you may want to create one Bluejay instance and use it everywhere, you can also create instances in specific portions of your app and tear them down after use. It's worth noting, however, that each instance of Bluejay has its own [CBCentralManager](https://developer.apple.com/documentation/corebluetooth/cbcentralmanager), which makes the multi-instance approach somewhat more complex.

Once you've created an instance, you can start the [Core Bluetooth](https://developer.apple.com/documentation/corebluetooth) session. You can do this during initialization of your app or view controller as appropriate. For example, in the demo app Bluejay is started inside `viewDidLoad` of the root view controller.

```swift
bluejay.start()
```

Bluejay needs to be started explicitly in order to support Core Bluetooth's State Restoration. State Restoration restores the Bluetooth stack and state when your app is restored from the background.

If you want to support [Background Mode](https://developer.apple.com/library/content/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html#//apple_ref/doc/uid/TP40013257-CH7-SW1) and [State Restoration](https://developer.apple.com/library/content/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html#//apple_ref/doc/uid/TP40013257-CH7-SW10) in your app, [it will take some extra work](#background-operation), which is necessary for Bluetooth apps that do work in the background.

Bluejay also supports [CoreBluetooth Migration](#corebluetooth-migration) for working with other Bluetooth libraries or your own.

### Bluetooth Events

The `ConnectionObserver` protocol allows a class to monitor and to respond to major Bluetooth and connection-related events:

```swift
public protocol ConnectionObserver: class {
    func bluetoothAvailable(_ available: Bool)
    func connected(to peripheral: Peripheral)
    func disconnected(from peripheral: Peripheral)
}
```

You can register a `ConnectionObserver` when starting Bluejay:

```swift
bluejay.start(mode: .new(StartOptions.bluejayDefault), connectionObserver: self)
```

Or you can add additional observers later using:

```swift
bluejay.register(observer: batteryLabel)
```

Unregistering an observer is not necessary, because Bluejay only holds weak references to registered observers, and Bluejay will clear nil observers from its list when they are found at the next event. But if you need to do so before that happens, you can use:

```swift
bluejay.unregister(observer: rssiLabel)
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

Bluejay has a powerful device scanning API that can be be used simply or customized to satisfy many use cases.

#### Basic Scanning

This simple call will just notify you when there is a new discovery, and when the scan has finished:

```swift
bluejay.scan(
    serviceIdentifiers: [heartRateService],
    discovery: { [weak self] (discovery, discoveries) -> ScanAction in
        guard let weakSelf = self else {
            return .stop
        }

        weakSelf.peripherals = discoveries
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

The stopped result contains a final list of discoveries available just before stopping, and an error if there is one.

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

Returning `blacklist` will ignore any future discovery of the same peripheral within the current scan session. This is only useful when `allowDuplicates` is set to true.

Returning `connect` will first stop the current scan, and have Bluejay make your connection request. This is useful if you want to connect right away when you've found the peripheral you're looking for. You can set up the `ConnectionResult` block outside the scan call to reduce callback nesting.

#### Monitoring

Another useful way to use the scanning API is to monitor the RSSI changes of nearby peripherals to estimate their proximity:

```swift
bluejay.scan(
    duration: 5,
    allowDuplicates: true,
    serviceIdentifiers: nil,
    discovery: { [weak self] (discovery, discoveries) -> ScanAction in
        guard let weakSelf = self else {
            return .stop
        }

        weakSelf.peripherals = discoveries
        weakSelf.tableView.reloadData()

        return .continue
    },
    expired: { [weak self] (lostDiscovery, discoveries) -> ScanAction in
        guard let weakSelf = self else {
            return .stop
        }

        debugPrint("Lost discovery: \(lostDiscovery)")

        weakSelf.peripherals = discoveries
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

Key parameters here are `allowDuplicates` and `expired`.

Setting `allowDuplicates` to true will stop coalescing multiple discoveries of the same peripheral into one single discovery callback. Instead, you'll get a discovery call every time a peripheral's advertising packet is picked up. This will consume more battery, and does not work in the background.

The `expired` callback is only invoked when `allowDuplicates` is true. This is called when Bluejay estimates that a previously discovered peripheral is likely out of range or no longer broadcasting. Essentially, when `allowDuplicates` is set to true, every time a peripheral is discovered a long timer associated with that peripheral starts counting down. If that peripheral is within range, and even if it has a slow broadcasting interval, it is likely that peripheral will be picked up by Core Bluetooth again and cause the timer to refresh. If not, it may be gone. Be aware that this is an estimation.

**Warning**: Setting `serviceIdentifiers` to `nil` will result in picking up all available Bluetooth peripherals in the vicinity, **but is not recommended by Apple**. It may cause battery and cpu issues on prolonged scanning, and **it also doesn't work in the background**. It is not a private API call, but an available option for situations where you need a quick solution, such as when experimenting or testing. Specifying at least one specific service identifier is the most common way to scan for Bluetooth devices in iOS. If you need to scan for all Bluetooth devices, we recommend making use of the `duration` parameter to stop the scan after 5 ~ 10 seconds to avoid scanning indefinitely and overloading the hardware.

### Connecting

It is important to keep in mind that Bluejay is designed to work with a single BLE peripheral. Multiple connections at once is not currently supported, and a connection request will fail if Bluejay is already connected or is still connecting. Although this can be a limitation for some sophisticated apps, it is more commonly a safeguard to ensure your app does not issue connections unnecessarily or erroneously.

```swift
bluejay.connect(peripheralIdentifier) { [weak self] (result) in
    switch result {
    case .success(let peripheral):
        debugPrint("Connection to \(peripheral.name) successful.")

	      guard let weakSelf = self else {
	          return
	      }

	      weakSelf.performSegue(withIdentifier: "showHeartSensor", sender: self)
    case .failure(let error):
        debugPrint("Connection to \(peripheral.name) failed with error: \(error.localizedDescription)")
    }
}
```

### Disconnect

To disconnect:

```swift
bluejay.disconnect()
```

Bluejay also supports finer controls over your disconnection:

#### Queued Disconnect

A queued disconnect will be queued like all other Bluejay API requests, so the disconnect attempt will wait for its turn until all the queued tasks before it finishes.

To perform a queued disconnect, simply:

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

### Cancel Everything

The reason why there is a `cancelEverything` API in addition to `disconnect`, is because sometimes we want to cancel everything in the queue but **without** disconnecting.

```swift
bluejay.cancelEverything(shouldDisconnect: false)
```

### Auto Reconnect

By default, `shouldAutoReconnect` is `true` and Bluejay will always try to automatically reconnect after an unexpected disconnection.

Bluejay will only set `shouldAutoReconnect` to `false` under these circumstances:

1. If you manually call `disconnect` and the disconnection is successful.
2. If you manually call `cancelEverything` and its disconnection is successful.

Bluejay will also **always** reset `shouldAutoReconnect` to `true` on a successful connection to a peripheral, as we usually want to reconnect to the same device as soon as possible if a connection is lost unexpectedly during normal usage.

However, there are some cases where auto reconnect is not desirable. In those cases, use a `DisconnectHandler`.

### Disconnect Handler

A disconnect handler is a single delegate that is suitable for performing major Bluetooth operations, such as restarting a scan, when there is a disconnection. Its singularity makes it a safer and more organized way to perform critical resuscitation tasks than the various callbacks you can install to various Bluejay requests, such as your connect, disconnect, read, and write calls. Ideally, when there is a disconnection, you should only clean up, update the UI, and perform certain safe and repeatable tasks in the callbacks of your regular Bluejay requests. Use the disconnect handler to perform one-time and major operations that you need to do at the end of a disconnection.

In addition to helping you avoid redundant and conflicted logic in various callbacks when there is a disconnection, the disconnect handler also allows you to evaluate and to control Bluejay's auto-reconnect behaviour.

For example, this delegate will turn off auto-reconnect whenever there is a disconnection.

```swift
func didDisconnect(from peripheral: Peripheral, with error: Error?, willReconnect autoReconnect: Bool) -> AutoReconnectMode {
    return .change(shouldAutoReconnect: false)
}
```

We also anticipate that for most apps, different view controllers may want to handle disconnection differently, so simply register and replace the existing disconnect handler as your user navigates to different parts of your app.

```swift
bluejay.registerDisconnectHandler(handler: self)
```

### Timeouts

You can also specify a timeout for a connection request, default is no timeout:

```swift
bluejay.connect(peripheralIdentifier, timeout: .seconds(15)) { ... }

public enum Timeout {
    case seconds(TimeInterval)
    case none
}
```

### Connection States

Your Bluejay instance has these properties to help you make connection-related decisions:

- `isBluetoothAvailable`
- `isConnecting`
- `isConnected`
- `isDisconnecting`
- `shouldAutoReconnect`
- `isScanning`

## Deserialization and Serialization

Reading, writing, and listening to Characteristics is straightforward in Bluejay. Most of the work involved is building out the deserialization and serialization of data. Let's have a quick look at how Bluejay helps standardize this process in your app via the `Receivable` and `Sendable` protocols.

#### Receivable

The models that represent data you wish to read and receive from your peripheral should all conform to the `Receivable` protocol.

Here is a partial example for the [Heart Rate Measurement Characteristic](https://www.bluetooth.com/specifications/gatt/viewer?attributeXmlFile=org.bluetooth.characteristic.heart_rate_measurement.xml):

```swift
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
        }
        else {
            measurement16bits = try bluetoothData.extract(start: 1, length: 2)
        }
    }

}
```

Note how you can use the `extract` function that Bluejay adds to `Data` to easily parse the bytes you need. We have plans to build more protection and error handling for this in the future.

Finally, while it is not essential and it will depend on the context, we suggest only exposing the needed and computed properties of your models.

#### Sendable

The models representing data you wish to send to your peripheral should all conform to the `Sendable` protocol.

In a nutshell, this is how you help Bluejay determine how to convert your models into `Data`:

```swift
struct WriteRequest: Sendable {

    var handle: UInt16
    var data: Sendable

    init(handle: UInt16, data: Sendable) {
        self.handle = handle
        self.data = data
    }

    func toBluetoothData() -> Data {
        let startByte = UInt8(0x3A)
        let payloadLength = UInt8(3 + (data.toBluetoothData().count))
        let command = UInt8(0x02)
        let handleInBigEndian = handle.bigEndian

        // The crc16CCITT function is a custom extension not available in either NSData nor Bluejay. It is included here just for demonstration purposes.
        let crc = (Bluejay.combine(sendables: [command, handleInBigEndian, data]) as NSData).crc16CCITT

        let request = Bluejay.combine(sendables: [
            startByte,
            payloadLength,
            command,
            handleInBigEndian,
            data,
            crc.bigEndian
            ])

        return request
    }

}
```

Note how we have a nested `Sendable` in this slightly more complicated model, as well as making use of the `combine` helper function to group and to arrange the data bytes in a particular order.

#### Sending and Receiving Primitives

In some cases, you may want to send or receive data that is simple enough that creating a custom struct that implements `Sendable` or `Receivable` to hold it is unnecessarily complicated. For those cases, Bluejay also retroactively conforms several built-in Swift types to `Sendable` and `Receivable`. `Int8`, `Int16`, `Int32`, `Int64`, `UInt8`, `UInt16`, `UInt32`, `UInt64`, `Data` and `String`are all conformed to both protocols and so can be sent or received directly.

`Int` and `UInt` are intentionally not conformed. Values are sent and/or received at a specific bit width. The intended bit width for an `Int` is ambiguous, and trying to use one often indicates a programmer error, in the form of not considering the bit width the Bluetooth device is expecting on a characteristic.

`String` is sent and/or received UTF8 encoded.

## Interactions

Once you have your data modelled using either the `Receivable` or `Sendable` protocol, the read, write, and listen APIs in Bluejay should handle the deserialization and serialization seamlessly for you. All you need to do is to specify the type for the generic result wrappers: `ReadResult<T>` or `WriteResult<T>`.

### Reading

Here is an example showing how to read the [sensor body location characteristic](https://www.bluetooth.com/specifications/gatt/viewer?attributeXmlFile=org.bluetooth.characteristic.body_sensor_location.xml), and converting its value to its corresponding label.

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
        weakSelf.sensorLocation = location
    case .failure(let error):
        debugPrint("Failed to read from sensor location with error: \(error.localizedDescription)")
    }
}
```

### Writing

Note that LightBlue Explorer's virtual heart sensor does not have write enabled for its sensor body location characteristic. See [Demo](#demo) to find out how to enable it. However, if write is not allowed, the error object in the failure block will inform you.

```swift
bluejay.write(to: sensorLocation, value: UInt8(indexPath.row), completion: { [weak self] (result) in
    guard let weakSelf = self else {
        return
    }

    switch result {
    case .success:
        debugPrint("Write to sensor location is successful.")

        if let selectedCell = weakSelf.selectedCell {
            selectedCell.accessoryType = .none
        }
        cell.accessoryType = .checkmark

        weakSelf.navigationController?.popViewController(animated: true)
    case .failure(let error):
        debugPrint("Failed to write to sensor location with error: \(error.localizedDescription)")
    }
})
```

### Listening

Listening involves waiting for the Bluetooth device to write to a specific characteristic. When that happens the app will be notified that the write has taken place and the completion block will be called with the value read from the characteristic.

Unlike read and write, where completion blocks are called very soon (generally at most a few seconds) after the original call and are called only once, listens are persistent. It could be minutes (or never) before the receive block is called, and the block can be called multiple times.

When you don't want to listen anymore, you **must** explicitly remove it with the `endListen` method.  You can only have one active listen on a given characteristic at a time.

Not all characteristics support listening, it is a feature that must be enabled for a characteristic on the Bluetooth device itself.

```swift
bluejay.listen(to: heartRateMeasurement) { [weak self] (result: ReadResult<HeartRateMeasurement>) in
    guard let weakSelf = self else {
        return
    }

    switch result {
    case .success(let heartRateMeasurement):
        debugPrint(heartRateMeasurement.measurement)
    case .failure(let error):
        debugPrint("Failed to listen to heart rate measurement with error: \(error.localizedDescription)")
    }
}
```

### Batch Operations

Often, your app needs to perform a longer series of reads, writes, and listens to complete a specific task, such as syncing, upgrading to a new firmware, or working with a notification-based Bluetooth module. In these cases, Bluejay provides an API for running all your operations on a background thread, and will call your completion on the main thread when everything finishes without an error, or if one of the operations has failed.

```swift
let heartRateService = ServiceIdentifier(uuid: "180D")
let heartRateMeasurement = CharacteristicIdentifier(uuid: "2A37", service: heartRateService)
let sensorLocation = CharacteristicIdentifier(uuid: "2A38", service: heartRateService)

bluejay.run(backgroundTask: { (peripheral) -> UInt8 in
    // 1. Stop monitoring.
    debugPrint("Reset step 1: stop monitoring.")
    try peripheral.endListen(to: heartRateMeasurement)

    // 2. Set sensor location to 0.
    debugPrint("Reset step 2: set sensor location to 0.")
    try peripheral.write(to: sensorLocation, value: UInt8(0))

    // 3. Read sensor location.
    debugPrint("Reset step 3: read sensor location.")
    let sensorLocation = try peripheral.read(from: sensorLocation) as UInt8

    /*
     Don't use the listen from the synchronized peripheral here to start monitoring the heart rate again, as it will actually block until it is turned off. The synchronous listen is for when you want to listen to and process some expected incoming values before moving on to the next steps in your background task. It is different from the regular asynchronous listen that is more commonly used for continuous monitoring.
     */

    // 4. Return the data interested and process it in the completion block on the main thread.
    debugPrint("Reset step 4: return sensor location.")
    return sensorLocation
}) { [weak self] (result: RunResult<UInt8>) in
    guard let weakSelf = self else {
        return
    }

    switch result {
    case .success(let sensorLocation):
        // Update the sensor location label on the main thread.
        weakSelf.updateSensorLocationLabel(value: sensorLocation)

        // Resume monitoring. Now we can use the non-blocking listen from Bluejay, not from the SynchronizedPeripheral.
        weakSelf.startMonitoringHeartRate()
    case .failure(let error):
        debugPrint("Failed to complete reset background task with error: \(error.localizedDescription)")
    }
}
```

It is critical though that when performing your Bluetooth operations in the background with `backgroundTask`, you **must** use the `SynchronizedPeripheral` given to you by this API. **DO NOT** call any `bluejay`.`read/write/listen` functions inside the `backgroundTask` block.

Note that because the `backgroundTask` block is running on a background thread, you need to be careful about accessing any global or captured data inside that block for thread safety reasons, like you would with any GCD or OperationQueue task. To help with this, Bluejay provides some other forms of `run(backgroundTask:completionOnMainThread:)` that allow you to pass user data into the background block and/or return a value from the background block that will be available in the success case of the result in the main thread block.

## Background Operation

[Background Execution](https://developer.apple.com/library/content/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/) is a mode supported by Core Bluetooth to allow apps to continue processing active Bluetooth operations when it is backgrounded or even when it is evicted from memory. For examples, a pending connect request that finishes, or a subscribed characteristic that fires a notification, can cause the system to wake or restart the app in the background. This can, for example, allow syncing data from a device without needing to manually launch the app.

In order to support background mode, make sure to turn on the **Background Modes** capability in your Xcode project with **Uses Bluetooth LE accessories** enabled.

Enabling background mode doesn't enable state restoration. State restoration is an additional behaviour on top of background mode that requires another step to setup.

### State Restoration

Once your project has BLE accessories background mode enabled, you can choose to opt in to State Restoration when you start your Bluejay session.

```swift
let startOptions = StartOptions(
  enableBluetoothAlert: true,
  backgroundRestore: .enable("com.steamclock.bluejay")
)
bluejay.start(mode: .new(startOptions), connectionObserver: self)
```

Additionally, Bluejay allows you to restore listen callbacks on subscribed characteristics that did not end when the app has stopped running.

```swift
let startOptions = StartOptions(
  enableBluetoothAlert: true,
  backgroundRestore: .enableWithListenRestorer("com.steamclock.bluejay", self)
)
bluejay.start(mode: .new(startOptions), connectionObserver: self)
```

### Listen Restoration

If State Restoration is enabled and your app has stopped running either due to memory pressure or by staying in the background past the allowed duration (this has been 3 minutes since iOS 7), then the next time your app is launched in the background or foreground, Bluejay will call the `willRestoreListen` function on your `ListenRestorer` during state restoration if there are any active listens preserved.

The listen restorer protocol looks like this:

```swift
/**
    A class protocol allowing notification of a characteristic being listened on, and provides an opportunity to restore its listen callback during Bluetooth state restoration.

    Bluetooth state restoration occurs when the background mode capability is turned on, and if the app is backgrounded or even terminated while a Bluetooth operation is still ongoing, iOS may keep the Bluetooth state alive, and attempt to restore it on resuming the app, so that the connection and operation between the app and the Bluetooth accessory is not interrupted and severed.
*/
public protocol ListenRestorer: class {
    /**
        Notify the conforming class that there is a characteristic being listened on, but it doesn't have any listen callbacks.

        - Note: Use the function `restoreListen` in Bluejay to restore the desired callback for the given characteristic and return true. Return false to prevent restoration, as well as to cancel the listening on the given characteristic.

        - Parameter on: the characterstic that is still being listened on when the CoreBluetooth stack is restored in the app.
        - Return: true if the characteristic's listen callback will be restored, false if the characteristic's listen should be cancelled and not restored.
    */
    func willRestoreListen(on characteristic: CharacteristicIdentifier) -> Bool
}
```


By default, if there is no `ListenRestorer` delegate provided in the `start` function, then Bluejay will cancel **all** active listens during state restoration.

Example:

```swift
extension ViewController: ListenRestorer {

    func willRestoreListen(on characteristic: CharacteristicIdentifier) -> Bool {
        if characteristic == heartRate {
            bluejay.restoreListen(to: heartRate, completion: { (result: ReadResult<UInt8>) in
                switch result {
                case .success(let value):
                    log.debug("Listen succeeded with value: \(value)")
                case .failure(let error):
                    log.debug("Listen failed with error: \(error.localizedDescription)")
                }
            })

            return true
        }

        return false
    }

}
```

## Advanced Usage

The following section will demonstrate a few advanced usage of Bluejay.

### Connect by Serial Number

In a project we've worked on, we had a device with a known serial number stored in a known characteristic that we want to connect to directly. However, Core Bluetooth doesn't support connection using a value from a characteristic.

To connect by serial number using Core Bluetooth, first you'd have to scan for the services you know your device is advertising. Once your device is picked up by the scan, then you can grab its CBPeripheral handle and connect to it. But after connecting to it, you still have to verify its serial number by discovering and reading the value from the containing characteristic. If the serial number is not a match, then you'd have to disconnect and repeat this process until you find the device with the serial number you're looking for.

Ideally, you'd want your Bluetooth vendor or engineer to include the serial number or any other important identifiers in the device's advertising packet. But more often than not, various resource constraints do apply, and we can't always expect everything to follow best practices perfectly. Luckily, Bluejay does make this easier.

Here is a detailed summary of what the code below does and why:

We are maintaining a local collection of "blacklisted" discoveries that persist over multiple scan sessions. These are devices that don't have matching serial numbers. We can't just rely on the scan function's "blacklist" `ScanAction` alone, because the scan function's blacklist shares the same lifecycle as the scan itself. And to allow enqueueing a connection to a device for verifying its serial number, the scan has to end first, so it can be removed from the top of the operation queue. Therefore, we have to start a new scan if the serial number doesn't match.

Since we are starting a new scan every time we find a device with an incorrect serial number, the brand new scan session can still pick up a device we've examined earlier. This is because the new scan session is unaware of devices previously blacklisted using the "blacklist" `ScanAction`. But, we can still find out whether a device is blacklisted using our **own** copy of the blacklist.

Returning `.blacklist` is not just a ceremonial task to ignore the current discovery within this scan session and to continue scanning. Doing so also adds some safety by preventing further discovery of the same device within the current scan session if `allowDuplicates` is set to true for some reasons. Interestingly, setting `allowDuplicates` to false has similar ignoring effect due to its coalescing behaviour, but we are doing this for an entirely different purpose – to save battery.

The keys to understanding this example is to keep in mind that there are **two** copies of blacklists at play here, and to understand why we need to stop and restart a new scan for every discovery that isn't what we're looking for. First, there is one blacklist we are **required** to maintain ourselves that persists over multiple scan sessions, because Bluejay's FIFO operation queue requires the scan to finish before it can run the connection task. Secondly, there's the blacklist that Bluejay maintains for a scan session, but it is cleared as soon as that scan is finished.

```swift
// Properties.
private var blacklistedDiscoveries = [ScanDiscovery]()    
private var targetSerialNumber: String?

// Scan by Serial Number function.
private func scan(services: [ServiceIdentifier], serialNumber: String) {
    debugPrint("Looking for peripheral with serial number \(serialNumber) to connect to.")

    statusLabel.text = "Searching..."

    bluejay.scan(
        allowDuplicates: false,
        serviceIdentifiers: services,
        discovery: { [weak self] (discovery, discoveries) -> ScanAction in
            guard let weakSelf = self else {
                return .stop
            }

            if weakSelf.blacklistedDiscoveries.contains(where: { (blacklistedDiscovery) -> Bool in
                return blacklistedDiscovery.peripheralIdentifier == discovery.peripheralIdentifier
            })
            {
                return .blacklist
            }
            else {
                return .connect(
                    discovery,
                    .none,
                    WarningOptions(notifyOnConnection: false, notifyOnDisconnection: true, notifyOnNotification: false), { (connectionResult) in
                    switch connectionResult {
                    case .success(let peripheral):
                        debugPrint("Connection to \(peripheral.name) successful.")

                        weakSelf.bluejay.read(from: Charactersitics.serialNumber, completion: { (readResult: ReadResult<String>) in
                            switch readResult {
                            case .success(let serialNumber):
                                if serialNumber == weakSelf.targetSerialNumber {
                                    debugPrint("Serial number matched.")

                                    weakSelf.statusLabel.text = "Connected"
                                }
                                else {
                                    debugPrint("Serial number mismatch.")

                                    weakSelf.blacklistedDiscoveries.append(discovery)

                                    weakSelf.bluejay.disconnect(completion: { (result) in
                                        switch result {
                                        case .success:
                                            weakSelf.scan(services: [Services.deviceInfo], serialNumber: weakSelf.targetSerialNumber!)
                                        case .failure(let error):
                                            preconditionFailure("Disconnect failed with error: \(error.localizedDescription)")
                                        }
                                    })
                                }
                            case .failure(let error):
                                debugPrint("Read serial number failed with error: \(error.localizedDescription).")

                                weakSelf.statusLabel.text = "Read Error: \(error.localizedDescription)"
                            }
                        })
                    case .failure(let error):
                        debugPrint("Connection to \(discovery.peripheralIdentifier) failed with error: \(error.localizedDescription)")

                        weakSelf.statusLabel.text = "Connection Error: \(error.localizedDescription)"
                    }
                })
            }
        }) { [weak self] (discoveries, error) in
        guard let weakSelf = self else {
            return
        }

        if let error = error {
            debugPrint("Scan stopped with error: \(error.localizedDescription)")

            weakSelf.statusLabel.text = "Scan Error: \(error.localizedDescription)"
        }
        else {
            debugPrint("Scan stopped without error.")
        }
    }
}
```

### Write and Assemble

One of the Bluetooth modules we've worked with doesn't always send back data in one packet, even if the data is smaller than its maximum allowed packet size. To handle these incoming data that can be broken up into any number of packets arbitrarily, we've introduced the `writeAndAssemble` API that is very similar to `writeAndListen` on the `SynchronizedPeripheral`. Therefore, at least for now, this is only supported in the context of `run(backgroundTask:completionOnMainThread:)`.

When using `writeAndAssemble`, we still expect you to know the total size of the data you are receiving, but Bluejay will keep listening and receiving packets until the expected size is reached before trying to deserialize the data into the object you need.

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

Some Bluetooth modules will pause sending data when it loses connection to your app, and will resume sending the same set of data from where it left off when the connection is re-established. This isn't an issue most of the time. However, if the connection loss is due to a crash in your app, or something that causes your listen callback to be deallocated before the connection is re-established, then it is often very difficult to resume your app with the exact same content and context at the time of the connection loss.

For example, you might have to re-authenticate the user when the app is re-opened. But if authentication requires listening to the same characteristic where the incomplete data set is still being sent, then you will be getting back unexpected values and most likely crash when trying to deserialize authentication related objects.

To handle this, it is often a good idea to flush a notifiable characteristic before starting a critical first-time and/or setup related operation. This is also only available on the `SynchronizedPeripheral` in the context of `run(backgroundTask:completionOnMainThread:)` for now.

```swift
try peripheral.flushListen(to: Characteristics.rigadoRX, idleWindow: 1, completion: {
    debugPrint("Flushed buffered data on RigadoRX.")
})
```

The `idleWindow` is in seconds, and basically specifies the duration of the absence of incoming data needed to predict that the flush is most likely completed. Note that this is still an estimation. Depending on your Bluetooth hardware and usage environments and conditions, a longer window might be necessary.

### CoreBluetooth Migration

If you want to start Bluejay with a pre-existing CoreBluetooth stack, you can do so using the `.use` start mode instead of `.new` when calling the `start` function.

```swift
bluejay.start(mode: .use(manager: anotherManager, peripheral: alreadyConnectedPeripheral))
```

You can also transfer Bluejay's CoreBluetooth stack to another Bluetooth library or your own using this function:

```swift
public func stopAndExtractBluetoothState() -> (manager: CBCentralManager, peripheral: CBPeripheral?)
```

Finally, you can check whether Bluejay has been started or stopped using the `hasStarted` property.

## API Documentation

We have more [in-depth API documentation for Bluejay](https://steamclock.github.io/bluejay/index.html) using inline documentation and Jazzy.
