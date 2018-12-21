//
//  SensorViewController.swift
//  BluejayHeartSensorDemo
//
//  Created by Jeremy Chiang on 2018-12-20.
//  Copyright © 2018 Steamclock Software. All rights reserved.
//

import Bluejay
import UIKit

class SensorViewController: UITableViewController {

    var sensor: PeripheralIdentifier?
    var heartRate: HeartRateMeasurement?

    override func viewDidLoad() {
        super.viewDidLoad()
        bluejay.register(connectionObserver: self)
    }

    override func willMove(toParent parent: UIViewController?) {
        if parent == nil {
            bluejay.disconnect(immediate: true) { result in
                switch result {
                case .disconnected:
                    debugPrint("Immediate disconnect is successful")
                case .failure(let error):
                    debugPrint("Immediate disconnect failed with error: \(error.localizedDescription)")
                }
            }
        }
    }

    deinit {
        debugPrint("Deinit SensorViewController")
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 3
        } else {
            return 4
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "detailCell", for: indexPath)

            if indexPath.row == 0 {
                cell.textLabel?.text = "Device Name"
                cell.detailTextLabel?.text = sensor?.name ?? ""
            } else if indexPath.row == 1 {
                cell.textLabel?.text = "Status"
                cell.detailTextLabel?.text = bluejay.isConnected ? "Connected" : "Disconnected"
            } else {
                cell.textLabel?.text = "Heart Rate"
                cell.detailTextLabel?.text = String(heartRate?.measurement ?? 0)

                DispatchQueue.main.async {
                    UIView.animate(withDuration: 0.25, animations: {
                        cell.detailTextLabel?.transform = cell.detailTextLabel!.transform.scaledBy(x: 1.5, y: 1.5)
                    }, completion: { completed in
                        if completed {
                            UIView.animate(withDuration: 0.25) {
                                cell.detailTextLabel?.transform = CGAffineTransform.identity
                            }
                        }
                    })
                }
            }

            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "buttonCell", for: indexPath)

            if indexPath.row == 0 {
                cell.textLabel?.text = "Connect"
            } else if indexPath.row == 1 {
                cell.textLabel?.text = "Disconnect"
            } else if indexPath.row == 2 {
                cell.textLabel?.text = "Listen to heart rate"
            } else if indexPath.row == 3 {
                cell.textLabel?.text = "End listen to heart rate"
            }

            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let selectedSensor = sensor else {
            debugPrint("No sensor found")
            return
        }

        if indexPath.section == 1 {
            let heartRateService = ServiceIdentifier(uuid: "180D")
            let heartRateCharacteristic = CharacteristicIdentifier(uuid: "2A37", service: heartRateService)

            if indexPath.row == 0 {
                bluejay.connect(selectedSensor, timeout: .seconds(15)) { result in
                    switch result {
                    case .success:
                        debugPrint("Connection attempt to: \(selectedSensor.description) is successful")
                    case .failure(let error):
                        debugPrint("Failed to connect to: \(selectedSensor.description) with error: \(error.localizedDescription)")
                    }
                }
            } else if indexPath.row == 1 {
                bluejay.disconnect()
            } else if indexPath.row == 2 {
                listen()
            } else if indexPath.row == 3 {
                bluejay.endListen(to: heartRateCharacteristic) { result in
                    switch result {
                    case .success:
                        debugPrint("End listen to heart rate is successful")
                    case .failure(let error):
                        debugPrint("End listen to heart rate failed with error: \(error.localizedDescription)")
                    }
                }
            }

            tableView.deselectRow(at: indexPath, animated: true)
        }
    }

    private func listen() {
        let heartRateService = ServiceIdentifier(uuid: "180D")
        let heartRateCharacteristic = CharacteristicIdentifier(uuid: "2A37", service: heartRateService)

        bluejay.listen(
            to: heartRateCharacteristic,
            multipleListenOption: .replaceable) { [weak self] (result: ReadResult<HeartRateMeasurement>) in
                guard let weakSelf = self else {
                    return
                }

                switch result {
                case .success(let heartRate):
                    weakSelf.heartRate = heartRate
                    weakSelf.tableView.reloadData()
                case .failure(let error):
                    debugPrint("Failed to listen to heart rate with error: \(error.localizedDescription)")
                }
        }
    }
}

extension SensorViewController: ConnectionObserver {
    func bluetoothAvailable(_ available: Bool) {
        debugPrint("SensorViewController - Bluetooth available: \(available)")

        tableView.reloadData()
    }

    func connected(to peripheral: PeripheralIdentifier) {
        debugPrint("SensorViewController - Connected to: \(peripheral.description)")

        sensor = peripheral
        listen()

        tableView.reloadData()
    }

    func disconnected(from peripheral: PeripheralIdentifier) {
        debugPrint("SensorViewController - Disconnected from: \(peripheral.description)")

        tableView.reloadData()
    }
}
