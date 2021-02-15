//
//  ScanViewController.swift
//  BluejayHeartSensorDemo
//
//  Created by Jeremy Chiang on 2018-12-20.
//  Copyright © 2018 Steamclock Software. All rights reserved.
//

import Bluejay
import UIKit

class ScanViewController: UITableViewController {

    var sensors: [ScanDiscovery] = []
    var selectedSensor: PeripheralIdentifier?

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(ScanViewController.appDidResume),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(ScanViewController.appDidBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        bluejay.registerDisconnectHandler(handler: self)
    }

    @objc func appDidResume() {
        scanHeartSensors()
    }

    @objc func appDidBackground() {
        bluejay.stopScanning()
    }

    private func scanHeartSensors() {
        if !bluejay.isScanning && !bluejay.isConnecting && !bluejay.isConnected {
            let heartRateService = ServiceIdentifier(uuid: "180D")

            bluejay.scan(
                allowDuplicates: true,
                serviceIdentifiers: [heartRateService],
                discovery: { [weak self] _, discoveries -> ScanAction in
                    guard let weakSelf = self else {
                        return .stop
                    }

                    weakSelf.sensors = discoveries
                    weakSelf.tableView.reloadData()

                    return .continue
                },
                expired: { [weak self] lostDiscovery, discoveries -> ScanAction in
                    guard let weakSelf = self else {
                        return .stop
                    }

                    debugLog("Lost discovery: \(lostDiscovery)")

                    weakSelf.sensors = discoveries
                    weakSelf.tableView.reloadData()

                    return .continue
                },
                stopped: { _, error in
                    if let error = error {
                        debugLog("Scan stopped with error: \(error.localizedDescription)")
                    } else {
                        debugLog("Scan stopped without error")
                    }
                })
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        bluejay.register(connectionObserver: self)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        bluejay.unregister(connectionObserver: self)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sensors.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "sensorCell", for: indexPath)

        cell.textLabel?.text = sensors[indexPath.row].peripheralIdentifier.name
        cell.detailTextLabel?.text = String(sensors[indexPath.row].rssi)

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedSensor = sensors[indexPath.row].peripheralIdentifier

        bluejay.connect(selectedSensor, timeout: .seconds(15)) { result in
            switch result {
            case .success:
                debugLog("Connection attempt to: \(selectedSensor.description) is successful")
            case .failure(let error):
                debugLog("Failed to connect to: \(selectedSensor.description) with error: \(error.localizedDescription)")
            }
        }
    }
}

extension ScanViewController: ConnectionObserver {
    func bluetoothAvailable(_ available: Bool, state: CBManagerState) {
        bluejay.log("ScanViewController - Bluetooth available: \(available)")

        if available {
            scanHeartSensors()
        } else if !available {
            sensors = []
            tableView.reloadData()
        }
    }

    func connected(to peripheral: PeripheralIdentifier) {
        debugLog("ScanViewController - Connected to: \(peripheral.description)")
        performSegue(withIdentifier: "showSensor", sender: self)
    }
}

extension ScanViewController: DisconnectHandler {
    func didDisconnect(from peripheral: PeripheralIdentifier, with error: Error?, willReconnect autoReconnect: Bool) -> AutoReconnectMode {
        if navigationController?.topViewController is ScanViewController {
            scanHeartSensors()
        }

        return .noChange
    }
}
