![Bluejay](bluejay-wordmark.png)

![CocoaPods Compatible](https://img.shields.io/cocoapods/v/Bluejay.svg)
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
  - [Background Mode](#background-mode)
  - [State Restoration](#state-restoration)
  - [Listen Restoration](#listen-restoration)
  - [Bluetooth Events](#bluetooth-events)
  - [Services and Characteristics](#services-and-characteristics)
  - [Scanning](#scanning)
  - [Connecting](#connecting)
- [Deserialization and Serialization](#deserialization-and-serialization)
  - [Receivable](#receivable)
  - [Sendable](#sendable)
- [Interactions](#interactions)
  - [Reading](#reading)
  - [Writing](#writing)
  - [Listening](#listening)
  - [Batch Operations](#batch-operations)

## Features

- A callback-based API
- A FIFO operation queue for more synchronous and predictable behaviour
- A background task mode for batch operations that avoids the "callback pyramid of death"
- Simple protocols for data serialization and deserialization
- An easy and safe way to observe connection states
- Listen restoration
- Extended error handling

## Requirements

- iOS 10 or above
- Xcode 8.2.1 or above
- Swift 3.2 or above

## Installation

Install using CocoaPods:

`pod 'Bluejay', '~> 0.1'`

Or to try the latest master:

`pod 'Bluejay', :git => 'https://github.com/steamclock/bluejay.git', :branch => 'master'`

Import using:

```swift
import Bluejay
```

## Demo

The iOS Simulator does not simulate Bluetooth. You may not have a Bluetooth LE peripheral handy, so we recommend trying Bluejay using a BLE peripheral simulator such as the [LightBlue Explorer App](https://itunes.apple.com/ca/app/lightblue-explorer-bluetooth/id557428110?mt=8).

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

## Usage

### Initialization

Create an instance of Bluejay:

```swift
let bluejay = Bluejay()
```

While you may want to create one Bluejay instance and use it everywhere, you can also create instances in specific portions of your app and tear them down after use. It's worth noting, however, that each instance of Bluejay has its own [CBCentralManager](https://developer.apple.com/documentation/corebluetooth/cbcentralmanager), which makes the multi-instance approach somewhat more complex.

Once you've created an instance, you can start the [Core Bluetooth](https://developer.apple.com/documentation/corebluetooth) session. You can do this during initialization of your app or view controller, as appropriate. For example, in the demo app Bluejay is started inside `viewDidLoad` of the root view controller.

```swift
bluejay.start()
```

Bluejay needs to be started explicitly in order to support Core Bluetooth's State Restoration. State Restoration restores the Bluetooth stack and state when your app is restored from the background.

If you want to support [Background Mode](https://developer.apple.com/library/content/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html#//apple_ref/doc/uid/TP40013257-CH7-SW1) and [State Restoration](https://developer.apple.com/library/content/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html#//apple_ref/doc/uid/TP40013257-CH7-SW10) in your app, it will take some extra work, but is critical for Bluetooth apps that do work in the background.

### Background Mode

In order to support background mode, make sure to turn on the **Background Modes** capability in your Xcode project with **Uses Bluetooth LE accessories** enabled.

Enabling background mode doesn't enable state restoration. State restoration is an additional behaviour on top of background mode that requires another step to setup.

### State Restoration

Once your project has BLE accessories background mode enabled, you can choose to opt in to State Restoration when you start your Bluejay session.

```swift
bluejay.start(backgroundRestore: .enable(yourRestoreIdentifier))
```

Additionally, Bluejay allows you to restore listen callbacks on subscribed characteristics that did not end when the app has stopped running.

```swift
bluejay.start(backgroundRestore: .enable(yourRestoreIdentifier, yourListenRestorer))
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

### Bluetooth Events

The `ConnectionObserver` protocol allows a class to monitor and respond to major Bluetooth and connection-related events:

```swift
public protocol ConnectionObserver: class {
    func bluetoothAvailable(_ available: Bool)
    func connected(_ peripheral: Peripheral)
    func disconected()
}
```

You can register a `ConnectionObserver` when starting Bluejay:

```swift
bluejay.start(connectionObserver: self)
```

Or you can add additional observers later using:

```swift
bluejay.register(observer: batteryLabel)
```

Unregistering an observer is not necessary, because Bluejay only holds weak references to registered observers. But if you need to do so, you can:

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

The stopped result contains all the discoveries made, and an error if there is one.

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

Finally, passing `nil` for the service identifiers will result in picking up all available Bluetooth peripherals in the vicinity. This consumes substantially more battery, and again, does not work in the background.

### Connecting

It is important to keep in mind that Bluejay is designed to work with a single BLE peripheral. Multiple connections at once is not currently supported, and a connection request will fail if Bluejay is already connected or is still connecting. Although this can be a limitation for some sophisticated apps, it is more commonly a safeguard to ensure your app does not issue connections unnecessarily or erroneously.

```swift
bluejay.connect(peripheralIdentifier) { [weak self] (result) in
    switch result {
    case .success(let peripheral):
	debugPrint("Connection to \(peripheral.identifier) successful.")

	guard let weakSelf = self else {
	    return
	}

	weakSelf.performSegue(withIdentifier: "showHeartSensor", sender: self)
    case .cancelled:
	debugPrint("Connection to \(peripheral.identifier) cancelled.")
    case .failure(let error):
	debugPrint("Connection to \(peripheral.identifier) failed with error: \(error.localizedDescription)")
    }
}
```

To disconnect:

```swift
bluejay.disconnect()
```

Rarely, a disconnect request can fail or get cancelled, so it is generally a good idea to make use of the completion block to provide error handling.

```swift
bluejay.disconnect { (result) in
    switch result {
    case .success(let peripheral):
	debugPrint("Disconnection from \(peripheral.identifier) successful.")
    case .cancelled:
	debugPrint("Disconnection from \(peripheralIdentifier.uuid.uuidString) cancelled.")
    case .failure(let error):
	debugPrint("Disconnection from \(peripheralIdentifier.uuid.uuidString) failed with error: \(error.localizedDescription)")
    }
}
```

#### Connection States

Your Bluejay instance has these properties to help you make connection-related decisions:

- `isBluetoothAvailable`
- `isConnecting`
- `isConnected`
- `isDisconnecting`
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

    init(bluetoothData: Data) {
        flags = bluetoothData.extract(start: 0, length: 1)

        isMeasurementIn8bits = (flags & 0b00000001) == 0b00000000

        if isMeasurementIn8bits {
            measurement8bits = bluetoothData.extract(start: 1, length: 1)
        }
        else {
            measurement16bits = bluetoothData.extract(start: 1, length: 2)
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

## Interactions

Once you have your data modelled using either the `Receivable` or `Sendable` protocol, the read, write, and listen APIs in Bluejay should handle the deserialization and serialization seamlessly for you. All you need to do is to specify the type for the generic result wrappers: `ReadResult<T>` or `WriteResult<T>`.

### Reading

```swift
bluejay.read(from: firmwareVersion) { [weak self] (result: ReadResult<FirmwareVersion>) in
    guard let weakSelf = self else {
	return
    }

    switch result {
    case .success(let firmwareVersion):
	debugPrint(firmwareVersion.string)
    case .cancelled:
	debugPrint("Read to firmware version cancelled.")
    case .failure(let error):
	debugPrint("Failed to read firmware version with error: \(error.localizedDescription)")
    }
}
```

### Writing

```swift
bluejay.write(to: nickname, value: newNickname) { [weak self] (result: WriteResult<Nickname>) in
    guard let weakSelf = self else {
	return
    }

    switch result {
    case .success:
	debugPrint("Write to nickanme successful.")
    case .cancelled:
	debugPrint("Write to nickname cancelled.")
    case .failure(let error):
	debugPrint("Failed to write to nickname with error: \(error.localizedDescription)")
    }
}
```

### Listening

```swift
bluejay.listen(to: heartRateMeasurement) { [weak self] (result: ReadResult<HeartRateMeasurement>) in
    guard let weakSelf = self else {
	return
    }

    switch result {
    case .success(let heartRateMeasurement):
	debugPrint(heartRateMeasurement.measurement)
    case .cancelled:
	debugPrint("Listen to heart rate measurement cancelled.")
    case .failure(let error):
	debugPrint("Failed to listen to heart rate measurement with error: \(error.localizedDescription)")
    }
}
```

### Batch Operations

Often, your app needs to perform a longer series of reads, writes, and listens to complete a specific task, such as syncing, upgrading to a new firmware, or working with a notification-based Bluetooth module. In these cases, Bluejay provides an API for running all your operations on a background thread, and will call your completion on the main thread when everything finishes without an error, or if one of the operations has failed.

```swift
bluejay.run(backgroundTask: { (peripheral) in
        var responseCode: ResponseCode?

        try peripheral.writeAndListen(
            writeTo: Characteristics.rigadoTX,
            value: WriteRequest(handle: Registers.configuration.motionControlEnable, data: enabled ? UInt8(1) : UInt8(0)),
            listenTo: Characteristics.rigadoRX,
            completion: { (result: WriteResponse) -> ListenAction in
                responseCode = ResponseCode(rawValue: result.responseCode)
                return .done
        })

        if responseCode != .ok {
            throw NSError(domain: "MyApp", code: 0, userInfo: [NSLocalizedDescriptionKey : "Failed writing to motion control enable."])
        }
    }, completionOnMainThread: { (result) in
        switch result {
        case .success:
            debugPrint("Motion control enable changed to: \(enabled)")            
        case .cancelled:
            debugPrint("Change motion control enable cancelled.")
        case .failure(let error):
            debugPrint("Failed to change motion control enable with error: \(error.localizedDescription)")
        }
    })
})
```

It is critical though that when performing your Bluetooth operations in the background with `backgroundTask`, you **must** use the `SynchronizedPeripheral` given to you by this API. **DO NOT** call any `bluejay`.`read/write/listen` functions inside the `backgroundTask` block.

## Documentaion

https://steamclock.github.io/bluejay/index.html
