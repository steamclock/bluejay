![Bluejay](bluejay-wordmark.png)

Bluejay is a simple Swift framework for building reliable Bluetooth LE apps.

Bluejay's primary goals are:
- Simplify talking to a single Bluetooth LE peripheral
- Make it easier to handle Bluetooth LE operations reliably
- Make good use of Swift features and conventions

## Features

- A callback-based API that can be more pleasant to work with than delegation in most cases
- A FIFO operation queue that allows more synchronous and predictable behaviours
- A background task mode to perform batch operations and avoid callback pyramids of death
- Simple protocols for data serialization and deserialization
- Easy and safe observation of Bluetooth and connection states
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

The Simulator does not simulate Bluetooth, and you may also not have access to a configurable Bluetooth LE peripheral right away, so we recommend trying Bluejay using a virtual BLE peripheral that can be set up using the [LightBlue Explorer](https://itunes.apple.com/ca/app/lightblue-explorer-bluetooth/id557428110?mt=8) app you can download for free from the App Store.

Bluejay has a demo app called **BluejayDemo** that works with LightBlue Explorer, and to see it in action:

1. Prepare two iOS devices – one will act as a virtual BLE peripheral, and the other will run the demo app which demonstrates how Bluejay can be used.
2. On the iOS device serving as the virtual BLE peripheral, go to the App Store and download LightBlue Explorer.
3. Launch LightBlue Explorer, and tap on the **Create Virtual Peripheral** button located at the bottom of the peripheral list.
4. For simplicity, choose **Heart Rate** from the base profile list, and finish by tapping the **Save** button.
5. Finally, build and run the **BluejayDemo** on the other iOS device, choose **Heart Rate Sensor** in the menu, and you will be able to start interacting with the virtual heart rate peripheral.

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

Depending on the nature of your app, you may want to create one single instance and use it throughout, or create one in a specific portion of your app and tear it down after use. Either way, the important thing to note here is that each instance of Bluejay has its own [CBCentralManager](https://developer.apple.com/documentation/corebluetooth/cbcentralmanager), and initializing Bluejay doesn't start the [Core Bluetooth](https://developer.apple.com/documentation/corebluetooth) session just yet.

Start Bluejay during initialization of your app or view controller, as appropriate. For example, in the demo app Bluejay is started inside `viewDidLoad` of the root view controller.

```swift
bluejay.start()
```

Bluejay needs to be started explicitly because in order to support listen restoration properly in a block-based API, we need to make sure the necessary objects are initialized and available before the Core Bluetooth stack is restored from the background.

However, state restoration is disabled by default in Bluejay. [Background mode](https://developer.apple.com/library/content/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html#//apple_ref/doc/uid/TP40013257-CH7-SW1) and [state restoration](https://developer.apple.com/library/content/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html#//apple_ref/doc/uid/TP40013257-CH7-SW10) are slightly complicated features, but important for apps that need to work in the background.

### Background Mode

In order to support background mode, make sure to turn on the **Background Modes** capability in your Xcode project with **Uses Bluetooth LE accessories** enabled.

Enabling background mode doesn't enable state restoration. State restoration is an additional behaviour on top of background mode that requires another step to setup.

### State Restoration

Once your project has BLE accessories background mode enabled, you can choose to opt-in to state restoration when you start your Bluejay session.

```swift
bluejay.start(backgroundRestore: .enable(yourRestoreIdentifier))
```

Additionally, Bluejay even allows you to restore listen callbacks on subscribed characteristics that did not end when the app has stopped running.

```swift
bluejay.start(backgroundRestore: .enable(yourRestoreIdentifier, yourListenRestorer))
```

### Listen Restoration

If state restoration is enabled and your app has stopped running either due to memory pressure or by staying in the background past the allowed duration (3 minutes since iOS 7), then the next time your app is launched in the background or foreground, Bluejay will call the `willRestoreListen` function on your `ListenRestorer` during state restoration if there are any active listens preserved.

The listen restorer protocol:

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

The `ConnectionObserver` protocol allows your class to monitor and respond to major Bluetooth and connection-related events:

```swift
public protocol ConnectionObserver: class {
    func bluetoothAvailable(_ available: Bool)
    func connected(_ peripheral: Peripheral)
    func disconected()
}
```

You can register an observer when starting Bluejay:

```swift
bluejay.start(connectionObserver: self)
```

Or you can add additional observers later using:

```swift
bluejay.register(observer: batteryLabel)
```

Unregistering an observer is not necessary, because Bluejay only holds weak references to registered observers. But if you require unregistering an observer explicitly, you can:

```swift
bluejay.unregister(observer: rssiLabel)
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

Bluejay requires using the `ServiceIdentifier` and `CharacteristicIdentifier` structs because this can help make it clear in your code whether you are working with a Service or a Characteristic, and prevents problems like mistakingly using or specifying a Service when a Characteristic is expected.

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

## Documentaion

https://steamclock.github.io/bluejay/overview.html
