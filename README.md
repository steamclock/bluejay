# Bluejay

Bluejay is a simple Swift framework for building reliable Bluetooth LE apps.

Bluejay's primary goals are:
- Simplify talking to a single Bluetooth LE peripheral
- Make it easier to handle Bluetooth LE operations reliably
- Make good use of Swift features and conventions

## Features

- A callback-based API that can be cleaner to work with than delegation
- Can perform batch operations in the background and avoid callback pyramids of death
- Makes the asynchronous Core Bluetooth API behave more synchronously
- Observable Bluetooth and connection states
- Listen restoration
- Extended error handling

## Requirements

- iOS 10 or above
- Xcode 8.2.1 or above
- Swift 3.2 or above

## Installation

Install using CocoaPods:

`pod 'Bluejay', :git => 'https://github.com/steamclock/bluejay.git', :branch => 'master'`

Import using:

```swift
import Bluejay
```

## Demo

The Simulator does not simulate Bluetooth, and you may also not have access to a configurable Bluetooth LE peripheral right away, so we recommend trying Bluejay using a virtual BLE peripheral. To set this up:

1. Prepare two iOS devices – one will act as a virtual BLE peripheral, and the other will run the BluejayDemo app which demonstrates how Bluejay can be used.
2. On the iOS device serving as the virtual BLE peripheral, go to the App Store and download the free [LightBlue Explorer](https://itunes.apple.com/ca/app/lightblue-explorer-bluetooth/id557428110?mt=8) app.
3. Open the "LightBlue Explorer" app, and tap on the "Create Virtual Peripheral" button located at the bottom of the peripheral list.
4. For simplicity, choose "Heart Rate" from the base profile list, and finish by tapping the "Save" button.
5. Finally, build and run the BluejayDemo app on the other iOS device, choose "Heart Rate Sensor" in the menu, and you will be able to start interacting with the virtual heart rate peripheral.

Notes:

- You can turn the virtual peripheral on or off in LightBlue Explorer by tapping the blue checkmark to the left of the peripheral's name.
	- If the virtual peripheral is not working as expected, you can try to reset it this way.
- The virtual peripheral will use your iPhone or iPad name, because the virtual peripheral is an extension of the host device.

## Usage

### Initialization

Start Bluejay during initialization of your app or view controller, as appropriate. For example, in the demo app Bluejay is started inside `viewDidLoad` of the root view controller.

```swift
bluejay.start(connectionObserver: self, listenRestorer: self, enableBackgroundMode: true)
```

Bluejay is started explicitly because this gives your app an opportunity to make sure the critical delegates are instantiated and available before the CoreBluetooth stack is initialized. This ensures that CoreBluetooth's startup and restoration events are handled.

Note:

Background mode is disabled by default. In order to support background mode, you must set the parameter `enableBackgroundMode` to true when you call `start`, as well as turn on the "Background Modes" capability in your Xcode project with "Uses Bluetooth LE accessories" enabled.

### Bluetooth Events

The `observer` conforms to the `ConnectionObserver` protocol, and allows the delegate to react to major connection-related events:

```swift
public protocol ConnectionObserver: class {
    func bluetoothAvailable(_ available: Bool)
    func connected(_ peripheral: Peripheral)
    func disconected()
}
```

You can add additional observers using:

```swift
bluejay.register(observer: batteryLabel)
```

Unregistering an observer is not typically necessary, because Bluejay only holds weak references to registered observers. But if you require unregistering an observer explicitly, use:

```swift
bluejay.unregister(observer: batteryLabel)
```

### Services & Characteristics

In Bluetooth parlance, a Service is a group of attributes, and a Characteristic is an attribute belonging to a category. For example, BLE peripherals that can detect heart rates usually have a Service named "Heart Rate" with a UUID of "180D". Inside that Service are Characteristics such as "Body Sensor Location" with a UUID of "2A38", as well as "Heart Rate Measurement" with a UUID of "2A37".

Many of these Services and Characteristics are standards specified by the Bluetooth SIG organization, and most hardware adopt their specifications. For example, most BLE peripherals have the Service "Device Information" with a UUID of "180A", where Characteristics such as firmware version, serial number, and other hardware details can be read and written. Of course, there are many BLE uses not covered by the Bluetooth Core Spec, and custom hardware often have their own unique Services and Characteristics.

Here is how you can specify Services and Characteristics for use in Bluejay:

```swift
let heartRateService = ServiceIdentifier(uuid: "180D")
let bodySensorLocation = CharacteristicIdentifier(uuid: "2A38", service: heartRateService)
let heartRate = CharacteristicIdentifier(uuid: "2A37", service: heartRateService)
```

### Scanning & Connecting

```swift
bluejay.scan(service: heartRateService) { (result) in
    switch result {
    case .success(let peripheral):
        log.debug("Scan succeeded with peripheral: \(peripheral.name)")

        self.bluejay.connect(PeripheralIdentifier(uuid: peripheral.identifier), completion: { (result) in
            switch result {
            case .success(let peripheral):
                log.debug("Connect succeeded with peripheral: \(peripheral.name)")
            case .failure(let error):
                log.debug("Connect failed with error: \(error.localizedDescription)")
            }
        })
    case .failure(let error):
        log.debug("Scan failed with error: \(error.localizedDescription)")
    }
}
```

```swift
bluejay.disconnect()
```

### Reading and Writing

```swift
bluejay.read(from: bodySensorLocation) { (result: ReadResult<IncomingString>) in
    switch result {
    case .success(let value):
        log.debug("Read succeeded with value: \(value.string)")
    case .failure(let error):
        log.debug("Read failed with error: \(error.localizedDescription)")
    }
}
```

```swift
bluejay.write(to: bodySensorLocation, value: OutgoingString("Wrist")) { (result) in
    switch result {
    case .success:
        log.debug("Write succeeded.")
    case .failure(let error):
        log.debug("Write failed with error: \(error.localizedDescription)")
    }
}
```

### Listening

```swift
bluejay.listen(to: heartRate) { (result: ReadResult<UInt8>) in
    switch result {
    case .success(let value):
        log.debug("Listen succeeded with value: \(value)")
    case .failure(let error):
        log.debug("Listen failed with error: \(error.localizedDescription)")
    }
}
```

```swift
bluejay.endListen(to: heartRate)
```

### Receivable & Sendable

The `Receivable` and `Sendable` protocols provide the blueprints to model the data packets being exchanged between the your app and the BLE peripheral, and are mandatory to type the results and the deliverables when using the `read` and `write` functions.

Examples:

```swift
struct IncomingString: Receivable {

    var string: String

    init(bluetoothData: Data) {
        string = String(data: bluetoothData, encoding: .utf8)!
    }

}

struct OutgoingString: Sendable {

    var string: String

    init(_ string: String) {
        self.string = string
    }

    func toBluetoothData() -> Data {
        return string.data(using: .utf8)!
    }

}
```

### Listen Restoration

Listen Restoration is how iOS supports background modes in Bluetooth LE.

From Apple's docs:

> [CoreBluetooth can] preserve the state of your app’s central and peripheral managers and to continue performing certain Bluetooth-related tasks on their behalf, even when your app is no longer running. When one of these tasks completes, the system relaunches your app into the background and gives your app the opportunity to restore its state and to handle the event appropriately.

Therefore, when your app has stopped running either due to memory pressure or by staying in the background past the allowed duration (3 minutes since iOS 7), then the next time your app is launched, the `ListenRestorer` protocol provides an opportunity to restore the lost callbacks to the still ongoing listens.

```swift
public protocol ListenRestorer: class {
    func willRestoreListen(on characteristic: CharacteristicIdentifier) -> Bool
}
```

By default, if there is no `ListenRestorer` delegate provided in the `start` function, then **all** active listens will effectively end when your app stops running.

The listen restorer can only be provided to Bluejay via its `start` function, because the restorer must be available to respond before CoreBluetooth initiates state restoration.

To restore the callback on the given characteristic, call the `restoreListen` function and return true, otherwise, return false and Bluejay will end listening on that characteristic for you:

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

## Documentaion

https://steamclock.github.io/bluejay/overview.html
