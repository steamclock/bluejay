//
//  SensorViewController.swift
//  BluejayHeartSensorDemo
//
//  Created by Jeremy Chiang on 2018-12-20.
//  Copyright © 2018 Steamclock Software. All rights reserved.
//

import Bluejay
import UIKit
import UserNotifications

let heartRateCharacteristic = CharacteristicIdentifier(
    uuid: "2A37",
    service: ServiceIdentifier(uuid: "180D")
)
let chirpCharacteristic = CharacteristicIdentifier(
    uuid: "83B4A431-A6F1-4540-B3EE-3C14AEF71A04",
    service: ServiceIdentifier(uuid: "CED261B7-F120-41C8-9A92-A41DE69CF2A8")
)

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
                    bluejay.log("Immediate disconnect is successful")
                case .failure(let error):
                    bluejay.log("Immediate disconnect failed with error: \(error.localizedDescription)")
                }
            }
        }
    }

    deinit {
        bluejay.log("Deinit SensorViewController")
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 3
        } else {
            return 6
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
            } else if indexPath.row == 4 {
                cell.textLabel?.text = "Listen to Dittojay"
            } else if indexPath.row == 5 {
                cell.textLabel?.text = "Stop listening to Dittojay"
            }

            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let selectedSensor = sensor else {
            bluejay.log("No sensor found")
            return
        }

        if indexPath.section == 1 {
            if indexPath.row == 0 {
                bluejay.connect(selectedSensor, timeout: .seconds(15)) { result in
                    switch result {
                    case .success:
                        bluejay.log("Connection attempt to: \(selectedSensor.description) is successful")
                    case .failure(let error):
                        bluejay.log("Failed to connect to: \(selectedSensor.description) with error: \(error.localizedDescription)")
                    }
                }
            } else if indexPath.row == 1 {
                bluejay.disconnect()
            } else if indexPath.row == 2 {
                listen(to: heartRateCharacteristic)
            } else if indexPath.row == 3 {
                endListen(to: heartRateCharacteristic)
            } else if indexPath.row == 4 {
                listen(to: chirpCharacteristic)
            } else if indexPath.row == 5 {
                endListen(to: chirpCharacteristic)
            }

            tableView.deselectRow(at: indexPath, animated: true)
        }
    }

    private func listen(to characteristic: CharacteristicIdentifier) {
        if characteristic == heartRateCharacteristic {
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
                        bluejay.log("Failed to listen to heart rate with error: \(error.localizedDescription)")
                    }
            }
        } else if characteristic == chirpCharacteristic {
            bluejay.listen(to: chirpCharacteristic, multipleListenOption: .trap) { (result: ReadResult<Data>) in
                switch result {
                case .success:
                    bluejay.log("Dittojay chirped.")

                    let content = UNMutableNotificationContent()
                    content.title = "Bluejay Heart Sensor"
                    content.body = "Dittojay chirped."

                    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                    UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
                case .failure(let error):
                    bluejay.log("Failed to listen to heart rate with error: \(error.localizedDescription)")
                }
            }
        }
    }

    private func endListen(to characteristic: CharacteristicIdentifier) {
        bluejay.endListen(to: characteristic) { result in
            switch result {
            case .success:
                bluejay.log("End listen to \(characteristic.description) is successful")
            case .failure(let error):
                bluejay.log("End listen to \(characteristic.description) failed with error: \(error.localizedDescription)")
            }
        }
    }
}

extension SensorViewController: ConnectionObserver {
    func bluetoothAvailable(_ available: Bool) {
        bluejay.log("SensorViewController - Bluetooth available: \(available)")

        tableView.reloadData()
    }

    func connected(to peripheral: PeripheralIdentifier) {
        bluejay.log("SensorViewController - Connected to: \(peripheral.description)")

        sensor = peripheral
        listen(to: heartRateCharacteristic)

        tableView.reloadData()

        let content = UNMutableNotificationContent()
        content.title = "Bluejay Heart Sensor"
        content.body = "Connected."

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    func disconnected(from peripheral: PeripheralIdentifier) {
        bluejay.log("SensorViewController - Disconnected from: \(peripheral.description)")

        tableView.reloadData()

        let content = UNMutableNotificationContent()
        content.title = "Bluejay Heart Sensor"
        content.body = "Disconnected."

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
