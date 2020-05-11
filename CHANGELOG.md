# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Changed

## [0.8.7] - 2020-05-11
### Added
- Added support for Swift Package Manager

## [0.8.6] - 2020-02-03
### Changed
- Bumped iOS target to 11 and recommended Xcode to 11.3.1

## [0.8.5] - 2019-05-06
### Changed
- Updated source and dependencies to support Swift 5

## [0.8.4] - 2019-04-05
### Fixed
- Fixed a crash when making a Bluejay call right after an explicit disconnect

## [0.8.3] - 2019-04-03
### Fixed
- Fixed disconnection clean up not working and crashing when it's caused by an unpairing attempt

## [0.8.2] - 2019-02-25
### Added
- Added initial support for did modify services delegation

## [0.8.1] - 2019-01-14
### Fixed
- Fixed and improved Carthage instruction

## [0.8.0] - 2019-01-11
### Added
- XCGLogger, and APIs for logging to a file and monitoring log file changes
- Dittojay demo app as a virtual Bluetooth LE heart rate sensor
  - Also allows testing background state restoration

### Changed
- Migrate to Swift 4.2
- Dropped support for iOS 9
- Removed outdated or soon-to-be-replaced demo projects and documentation
- Redo, clean up, and improve Bluejay demo app to work with Dittojay demo.
- Restrict public access to `Peripheral`

### Fixed
- Background and listen restoration callbacks
- Multiple listen crash by allowing trapping or replacing an existing listen
- Order of queueing when discovering services and characteristics
- Thread-related crashes by adding main thread safety checks to important Bluejay API calls

## [0.7.1] - 2018-12-06
- Add SwiftLint
- Add custom SwiftLint yaml with minor alterations
- Conform all files to SwiftLint suggestions

## [0.7.0] - 2018-11-02
- Add StartMode to better encapsulate CBCentralManager initialization options
- Add WarningOptions to better encapsulate connect warning options
- Fix handling of expected and unexpected disconnections
- Add disconnect handler to handle auto-reconnect
- Remove all cancellation callbacks; use existing failure blocks and look for BluejayError.cancelled instead if you need to differentiate between a failure caused by cancellation versus a failure caused by other errors
- Return Bluejay Peripheral instead of CBPeripheral for connect, disconnect, and RSSI observer callbacks; so that you don't have to import CoreBluetooth in many of your files anymore, and you can also get a "better/more suitable" peripheral object to work with
- Fix a scan crash caused by not clearing the scan request's global timer
- Remove set privileges on all public Bluejay instance variables; they are all supposed to be read only from the get go, but a few were settable and that was dangerous

## [0.6.5] - 2018-10-22
### Added
- Added an option to `scan` to change the threshold for ignoring discoveries based on insignificant changes to RSSI

## [0.6.4] - 2018-08-02
### Added
- Added warnings against using `scan` with `serviceIdentifiers` set to `nil` or empty.

## [0.6.3] - 2018-07-26
### Added
- Add API to check whether a peripheral is listening to a characteristic
- Allow disabling auto-reconnect when using cancelEverything
- Expose auto-reconnect variable
- Update readme, changelog, and documentation

## [0.6.2] - 2018-05-01
### Fixed
- Fix podspec

## [0.6.1] - 2018-05-01
### Fixed
- Fix all Xcode 9.3 warnings

## [0.6.0] - 2018-05-01
### Added
- Add a new API to allow shutting down Bluejay and transfer the CoreBluetooth manager and delegate to another library or code

## [0.5.1] - 2018-04-09
### Fixed
- We weren't using the correct key name to access the listen cache, so listen restoration was broken. This should now be fixed.

## [0.5.0] - 2018-04-09
### Fixed
- There was a subtle true/false reversal mistake that we didn't catch when bringing in the new error enums. This was causing the second connection request to cancel the first ongoing connection request.

## [0.4.9] - 2018-04-09
### Fixed
- Prevent indefinite flush listen
- Add missing cancellation handling for flush listen
- Dedup listen semaphore signals in flush listen
- Add missing semaphore signal for end listen for flush listen
- Use timeout enum in flush listen

## [0.4.8] - 2018-03-16
### Added
- Add timeout to synchronized listen, which allows handling stale or stuck listens when using the run background task.

## [0.4.7] - 2018-03-16
### Added
- Expose peripheral maximum write size API. Useful when EDL is needed and the maximum write size is unknown.

## [0.4.6] - 2018-02-27
### Fixed
- Connecting immediately after a disconnect wasn't possible due to a strict and slightly incorrect double connect protection. This has been fixed now.

## [0.4.5] - 2018-02-26
### Fixed
- Better management of semaphore locks and releases for write and assemble
- Better usage of end listen for write and assemble
- Allow failing write and assemble if bluetooth becomes unavailable or if there's a disconnection after both the read and listen have been setup correctly

## [0.4.4] - 2018-02-09
### Added
- Use `isBluetoothStateUpdateImminent` to check whether the central manager state is unknown or resetting

## [0.4.3] - 2018-02-05
### Fixed
- Allow certain end listen calls in the writeAndListen API to propagate disconnect errors back to the synchronized peripheral correctly.

## [0.4.2] - 2018-02-05
### Fixed
- If there is a disconnect while a background task is running, defer the disconnection clean up it to the end of the background task to allow proper tear down of the Bluejay states
- Fix auto reconnect states to allow proper reconnection when expected

## [0.4.1] - 2018-02-01
### Fixed
- Improve handling and exiting the locks in write and listen for synchronized peripheral
- Improve handling of end listen completion for synchronized peripheral
- Improve handling of state restoration for the connecting and disconnecting states
- Fix connection timeout not working as expected

## [0.4.0] - 2018-01-24
### Changed
- Make specifying a connection timeout required

## [0.3.0] - 2017-10-11
### Changed
- Migrate to Swift 4
- Use Xcode 9 settings
- Use Codable to encode and decode ListenCache
- Specify Swift 4 for CocoaPods
- Update documentation

## [0.2.0] - 2017-09-14
### Changed
- Make Receivable and Data+Extractable throwable

## [0.1.2] - 2017-08-15
### Changed
- Support iOS 9.3 again
- Support Carthage
- Improve disconnection and auto reconnect
- Add more documentation

### Fixed
- Fix caching of listens

## [0.1.1] - 2017-07-10
### Changed
- Support iOS 10 and above only

## [0.1.0] - 2017-06-26
### Added
- Initial public release
