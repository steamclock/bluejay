//
//  Scan.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-18.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import CoreBluetooth
import Foundation
import UIKit

/// A scan operation.
class Scan: Queueable {

    /// The queue this operation belongs to.
    var queue: Queue?

    /// The state of this operation.
    var state: QueueableState

    /// The manager responsible for this operation.
    private let manager: CBCentralManager

    /// The duration of the scan.
    private let duration: TimeInterval

    /// The timer that completes when timeout equal to `duration` occurs.
    private var timeoutTimer: Timer?

    /// If allowDuplicates is true, the scan will repeatedly discover the same device as long as its advertisement is picked up. This is a Core Bluetooth option, and it does consume more battery, doesn't work in the background, and is often advised to turn off.
    private let allowDuplicates: Bool

    /// Throttle discoveries by ignoring discovery if the change in RSSI is insignificant. 0 will never throttle discoveries, default is 5 dBm.
    private let throttleRSSIDelta: Int

    /// The scan will only look for peripherals broadcasting the specified services.
    private let serviceIdentifiers: [ServiceIdentifier]?

    /// The discovery callback.
    private let discovery: (ScanDiscovery, [ScanDiscovery]) -> ScanAction

    /// The expired callback.
    private let expired: ((ScanDiscovery, [ScanDiscovery]) -> ScanAction)?

    /// The stopped callback. Called when stopped normally as well, not just when there is an error.
    private let stopped: ([ScanDiscovery], Error?) -> Void

    /// The discoveries made so far in a given scan session.
    private var discoveries = [ScanDiscovery]()

    /// The blacklisted discoveries collected so far in a gvien scan session.
    private var blacklist = [ScanDiscovery]()

    /// The timers used to estimate an expiry callback, indicating that the peripheral is potentially no longer accessible.
    private var timers = [(UUID, Timer?)]()

    init(duration: TimeInterval,
         allowDuplicates: Bool,
         throttleRSSIDelta: Int,
         serviceIdentifiers: [ServiceIdentifier]?,
         discovery: @escaping (ScanDiscovery, [ScanDiscovery]) -> ScanAction,
         expired: ((ScanDiscovery, [ScanDiscovery]) -> ScanAction)?,
         stopped: @escaping ([ScanDiscovery], Error?) -> Void,
         manager: CBCentralManager) {
        self.state = .notStarted

        self.duration = duration
        self.allowDuplicates = allowDuplicates
        self.throttleRSSIDelta = throttleRSSIDelta
        self.serviceIdentifiers = serviceIdentifiers
        self.discovery = discovery
        self.expired = expired
        self.stopped = stopped
        self.manager = manager

        if serviceIdentifiers?.isEmpty != false {
            debugLog("""
                Warning: Setting `serviceIdentifiers` to `nil` is not recommended by Apple. \
                It may cause battery and cpu issues on prolonged scanning, and **it also doesn't work in the background**. \
                If you need to scan for all Bluetooth devices, we recommend making use of the `duration` parameter to stop the scan \
                after 5 ~ 10 seconds to avoid scanning indefinitely and overloading the hardware.
                """)
        }
    }

    deinit {
        debugLog("Scan deinitialized")
    }

    func start() {
        state = .running

        if duration > 0 {
            let timeoutTimer = Timer(
                timeInterval: duration,
                target: self,
                selector: #selector(timeoutTimerAction(_:)),
                userInfo: nil,
                repeats: false)
            let runLoop: RunLoop = .current
            runLoop.add(timeoutTimer, forMode: RunLoop.Mode.default)
            self.timeoutTimer = timeoutTimer
        }

        let services = serviceIdentifiers?.map { element -> CBUUID in
            element.uuid
        }

        manager.scanForPeripherals(withServices: services, options: [CBCentralManagerScanOptionAllowDuplicatesKey: allowDuplicates])

        if allowDuplicates {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(didEnterBackgroundWithAllowDuplicates),
                name: UIApplication.didEnterBackgroundNotification,
                object: nil
            )
        }

        if serviceIdentifiers == nil {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(didEnterBackgroundWithoutServiceIdentifiers),
                name: UIApplication.didEnterBackgroundNotification,
                object: nil
            )
        }

        debugLog("Scanning started.")
    }

    func process(event: Event) {
        if case .didDiscoverPeripheral(let cbPeripheral, let advertisementData, let rssi) = event {
            let peripheralIdentifier = PeripheralIdentifier(uuid: cbPeripheral.identifier, name: cbPeripheral.name)

            let newDiscovery = ScanDiscovery(
                peripheralIdentifier: peripheralIdentifier,
                advertisementPacket: advertisementData,
                rssi: rssi.intValue)

            // Ignore discovery if it is blacklisted.
            if blacklist.contains(where: { blacklistedDiscovery -> Bool in
                newDiscovery.peripheralIdentifier == blacklistedDiscovery.peripheralIdentifier
            }) {
                return
            }

            // Exit function early if discovery is to be blacklisted.
            if case .blacklist = discovery(newDiscovery, discoveries) {
                blacklist.append(newDiscovery)
                return
            }

            // Only predict losing signals to broadcasting peripherals if allow duplicates is enabled, as that mode is mostly used in monitoring context where we need to keep track of advertising peripherals continously.
            if allowDuplicates {
                refreshTimer(identifier: newDiscovery.peripheralIdentifier.uuid)
            }

            if let indexOfExistingDiscovery = discoveries.firstIndex(where: { existingDiscovery -> Bool in
                existingDiscovery.peripheralIdentifier == peripheralIdentifier
            }) {
                let existingDiscovery = discoveries[indexOfExistingDiscovery]

                // Throttle discovery by ignoring discovery if the change of RSSI is insignificant.
                if abs(existingDiscovery.rssi - rssi.intValue) < throttleRSSIDelta {
                    return
                }

                // Update existing discovery.
                discoveries.remove(at: indexOfExistingDiscovery)
                discoveries.insert(newDiscovery, at: indexOfExistingDiscovery)
            } else {
                discoveries.append(newDiscovery)
            }

            if case .stop = discovery(newDiscovery, discoveries) {
                state = .completed
                stopScan(with: discoveries, error: nil)
            } else if case .connect(let discovery, let timeout, let warningOptions, let completion) = discovery(newDiscovery, discoveries) {
                state = .completed
                stopScan(with: discoveries, error: nil)

                if let queue = queue {
                    if let cbPeripheral = manager.retrievePeripherals(withIdentifiers: [discovery.peripheralIdentifier.uuid]).first {
                        queue.add(Connection(
                            peripheral: cbPeripheral,
                            manager: manager,
                            timeout: timeout,
                            warningOptions: warningOptions,
                            callback: completion)
                        )
                    } else {
                        completion(.failure(BluejayError.unexpectedPeripheral(discovery.peripheralIdentifier)))
                    }
                } else {
                    preconditionFailure("Could not connect at the end of a scan: queue is nil.")
                }
            }
        } else {
            preconditionFailure("Unexpected event response: \(event)")
        }
    }

    func stop() {
        state = .completed
        stopScan(with: discoveries, error: nil)
    }

    func fail(_ error: Error) {
        state = .failed(error)
        stopScan(with: discoveries, error: error)
    }

    @objc func didEnterBackgroundWithAllowDuplicates() {
        fail(BluejayError.allowDuplicatesInBackgroundNotSupported)
    }

    @objc func didEnterBackgroundWithoutServiceIdentifiers() {
        fail(BluejayError.missingServiceIdentifiersInBackground)
    }

    private func stopScan(with discoveries: [ScanDiscovery], error: Error?) {
        clearTimers()

        // There is no point trying to stop the scan if Bluetooth off, as trying to do so has no effect and will also cause CoreBluetooth to log an "API MISUSE" warning.
        if manager.state == .poweredOn {
            manager.stopScan()
        }

        if let error = error {
            debugLog("Scanning stopped with error: \(error.localizedDescription)")
        } else {
            debugLog("Scanning stopped.")
        }

        stopped(discoveries, error)

        // swiftlint:disable:next notification_center_detachment
        NotificationCenter.default.removeObserver(self)

        updateQueue()
    }

    private func refreshTimer(identifier: UUID) {
        if let indexOfExistingTimer = timers.firstIndex(where: { uuid, _ -> Bool in
            uuid == identifier
        }) {
            timers[indexOfExistingTimer].1?.invalidate()
            timers[indexOfExistingTimer].1 = nil
            timers.remove(at: indexOfExistingTimer)
        }

        var timer: Timer?

        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { [weak self] _ in
            guard let weakSelf = self else {
                return
            }
            weakSelf.refresh(identifier: identifier)
        }

        timers.append((identifier, timer!))
    }

    private func refresh(identifier: UUID) {
        if state.isFinished {
            return
        }

        if let indexOfExpiredDiscovery = discoveries.firstIndex(where: { discovery -> Bool in
            discovery.peripheralIdentifier.uuid == identifier
        }) {
            let expiredDiscovery = discoveries[indexOfExpiredDiscovery]
            discoveries.remove(at: indexOfExpiredDiscovery)

            if let expired = expired {
                if case .stop = expired(expiredDiscovery, discoveries) {
                    DispatchQueue.main.async {
                        self.clearTimers()

                        self.manager.stopScan()
                        self.state = .completed

                        self.stopped(self.discoveries, nil)
                    }
                }
            }
        }
    }

    @objc func refresh(timer: Timer) {
        if let identifier = timer.userInfo as? UUID {
            refresh(identifier: identifier)
        }
    }

    private func clearTimers() {
        for timerIndex in 0..<timers.count {
            timers[timerIndex].1?.invalidate()
            timers[timerIndex].1 = nil
        }

        timers = []

        timeoutTimer?.invalidate()
        timeoutTimer = nil
    }

    @objc func timeoutTimerAction(_ timer: Timer) {
        self.timeoutTimer = nil

        switch state {
        case .notStarted, .stopping, .failed, .completed:
            preconditionFailure("Scan timer expired when state was: \(state.description)")
        case .running:
            state = .completed

            debugLog("Finished scanning on timeout.")

            stopScan(with: discoveries, error: nil)
        }
    }
}
