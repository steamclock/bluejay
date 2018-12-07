//
//  ScanHeartRateSensorsViewController.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-05-15.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Bluejay
import UIKit

class ScanHeartRateSensorsViewController: UITableViewController {

    private let bluejay = Bluejay()

    private var peripherals = [ScanDiscovery]() {
        didSet {
            peripherals.sort { periphA, periphB -> Bool in
                periphA.rssi < periphB.rssi
            }
        }
    }

    private var selectedPeripheralIdentifier: PeripheralIdentifier?

    override func viewDidLoad() {
        super.viewDidLoad()

        clearsSelectionOnViewWillAppear = true

        let startOptions = StartOptions(
            enableBluetoothAlert: true,
            backgroundRestore: .enableWithListenRestorer("com.steamclock.bluejay", self, self)
        )
        bluejay.start(mode: .new(startOptions), connectionObserver: self)

        scanHeartSensors()
    }

    private func scanHeartSensors() {
        let heartRateService = ServiceIdentifier(uuid: "180D")

        bluejay.scan(
            allowDuplicates: true,
            serviceIdentifiers: [heartRateService],
            discovery: { [weak self] _, discoveries -> ScanAction in
                guard let weakSelf = self else {
                    return .stop
                }

                weakSelf.peripherals = discoveries
                weakSelf.tableView.reloadData()

                return .continue
            },
            expired: { [weak self] lostDiscovery, discoveries -> ScanAction in
                guard let weakSelf = self else {
                    return .stop
                }

                debugPrint("Lost discovery: \(lostDiscovery)")

                weakSelf.peripherals = discoveries
                weakSelf.tableView.reloadData()

                return .continue
            },
            stopped: { _, error in
                if let error = error {
                    debugPrint("Scan stopped with error: \(error.localizedDescription)")
                } else {
                    debugPrint("Scan stopped without error.")
                }
            })
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if bluejay.isConnecting || bluejay.isConnected {
            bluejay.disconnect { [weak self] result in
                guard let weakSelf = self else {
                    return
                }

                switch result {
                case .disconnected:
                    if !weakSelf.bluejay.isScanning {
                        DispatchQueue.main.async {
                            weakSelf.scanHeartSensors()
                        }
                    }
                case .failure(let error):
                    preconditionFailure("Disconnect failed with error: \(error.localizedDescription)")
                }
            }
        } else if !bluejay.isScanning {
            scanHeartSensors()
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return peripherals.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "heartCell", for: indexPath)

        cell.textLabel?.text = peripherals[indexPath.row].peripheralName ?? "Unknown"
        cell.detailTextLabel?.text = "RSSI: \(peripherals[indexPath.row].rssi)"

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let peripheral = peripherals[indexPath.row]

        let peripheralIdentifier = peripherals[indexPath.row].peripheralIdentifier
        selectedPeripheralIdentifier = peripheralIdentifier

        bluejay.connect(peripheralIdentifier, timeout: .none) { [weak self] result in
            switch result {
            case .success(let peripheral):
                debugPrint("Connection to \(peripheral.name) successful.")

                guard let weakSelf = self else {
                    return
                }

                weakSelf.performSegue(withIdentifier: "showHeartSensor", sender: self)
            case .failure(let error):
                debugPrint("Connection to \(peripheral.peripheralIdentifier) failed with error: \(error.localizedDescription)")
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showHeartSensor", let destination = segue.destination as? HeartSensorViewController {
            destination.bluejay = bluejay
            destination.peripheralIdentifier = selectedPeripheralIdentifier
        }
    }
}

extension ScanHeartRateSensorsViewController: ConnectionObserver {

    func bluetoothAvailable(_ available: Bool) {
        debugPrint("Bluetooth available: \(available)")

        if available && !bluejay.isScanning && navigationController?.topViewController == self {
            scanHeartSensors()
        }
    }

    func connected(to peripheral: Peripheral) {
        debugPrint("Connected to \(peripheral)")
    }

    func disconnected() {
        debugPrint("Disconnected")
    }

}

extension ScanHeartRateSensorsViewController: ListenRestorer {

    func willRestoreListen(on characteristic: CharacteristicIdentifier) -> Bool {
        return false
    }

}

extension ScanHeartRateSensorsViewController: BackgroundRestorer {
    func didRestoreConnection(to peripheral: Peripheral) -> BackgroundRestoreCompletion {
        return { [weak self] in
            guard let weakSelf = self else {
                return
            }

            weakSelf.selectedPeripheralIdentifier = peripheral.uuid
            weakSelf.performSegue(withIdentifier: "showHeartSensor", sender: self)
        }
    }

    func didFailToRestoreConnection(to peripheral: Peripheral, error: Error) -> BackgroundRestoreCompletion {
        return { [weak self] in
            guard let weakSelf = self else {
                return
            }

            weakSelf.scanHeartSensors()
        }
    }

}
