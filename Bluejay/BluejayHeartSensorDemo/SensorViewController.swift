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
let pairingCharacteristic = CharacteristicIdentifier(
    uuid: "E4D4A76C-B9F1-422F-8BBA-18508356A145",
    service: ServiceIdentifier(uuid: "16274BFE-C539-416C-9646-CA3F991DADD6")
)

class SensorViewController: UITableViewController {

    var sensor: PeripheralIdentifier?
    var heartRate: HeartRateMeasurement?

    override func viewDidLoad() {
        super.viewDidLoad()
        bluejay.register(connectionObserver: self)
        bluejay.register(serviceObserver: self)
    }

    override func willMove(toParent parent: UIViewController?) {
        if parent == nil {
            bluejay.disconnect(immediate: true) { result in
                switch result {
                case .disconnected:
                    debugLog("Immediate disconnect is successful")
                case .failure(let error):
                    debugLog("Immediate disconnect failed with error: \(error.localizedDescription)")
                }
            }
        }
    }

    deinit {
        debugLog("Deinit SensorViewController")
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 3
        } else {
            return 8
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
            } else if indexPath.row == 6 {
                cell.textLabel?.text = "Terminate app"
            } else if indexPath.row == 7 {
                cell.textLabel?.text = "Pair"
            }

            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let selectedSensor = sensor else {
            debugLog("No sensor found")
            return
        }

        if indexPath.section == 1 {
            if indexPath.row == 0 {
                bluejay.connect(selectedSensor, timeout: .seconds(15)) { result in
                    switch result {
                    case .success:
                        debugLog("Connection attempt to: \(selectedSensor.description) is successful")
                    case .failure(let error):
                        debugLog("Failed to connect to: \(selectedSensor.description) with error: \(error.localizedDescription)")
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
            } else if indexPath.row == 6 {
                kill(getpid(), SIGKILL)
            } else if indexPath.row == 7 {
                bluejay.read(from: pairingCharacteristic) { (result: ReadResult<Data>) in
                    switch result {
                    case .success(let data):
                        debugLog("Pairing success: \(String(data: data, encoding: .utf8) ?? "")")
                    case .failure(let error):
                        debugLog("Pairing failed with error: \(error.localizedDescription)")
                    }
                }
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
                        debugLog("Failed to listen to heart rate with error: \(error.localizedDescription)")
                    }
            }
        } else if characteristic == chirpCharacteristic {
            bluejay.listen(to: chirpCharacteristic, multipleListenOption: .replaceable) { (result: ReadResult<Data>) in
                switch result {
                case .success:
                    debugLog("Dittojay chirped.")

                    let content = UNMutableNotificationContent()
                    content.title = "Bluejay Heart Sensor"
                    content.body = "Dittojay chirped."

                    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                    UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
                case .failure(let error):
                    debugLog("Failed to listen to heart rate with error: \(error.localizedDescription)")
                }
            }
        }
    }

    private func endListen(to characteristic: CharacteristicIdentifier) {
        bluejay.endListen(to: characteristic) { result in
            switch result {
            case .success:
                debugLog("End listen to \(characteristic.description) is successful")
            case .failure(let error):
                debugLog("End listen to \(characteristic.description) failed with error: \(error.localizedDescription)")
            }
        }
    }
}

extension SensorViewController: ConnectionObserver {
    func bluetoothAvailable(_ available: Bool, state: CBManagerState) {
        bluejay.log("SensorViewController - Bluetooth available: \(available)")

        tableView.reloadData()
    }

    func connected(to peripheral: PeripheralIdentifier) {
        debugLog("SensorViewController - Connected to: \(peripheral.description)")

        sensor = peripheral
        listen(to: heartRateCharacteristic)
        listen(to: chirpCharacteristic)

        tableView.reloadData()

        let content = UNMutableNotificationContent()
        content.title = "Bluejay Heart Sensor"
        content.body = "Connected."

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    func disconnected(from peripheral: PeripheralIdentifier) {
        debugLog("SensorViewController - Disconnected from: \(peripheral.description)")

        tableView.reloadData()

        let content = UNMutableNotificationContent()
        content.title = "Bluejay Heart Sensor"
        content.body = "Disconnected."

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}

extension SensorViewController: ServiceObserver {
    func didModifyServices(from peripheral: PeripheralIdentifier, invalidatedServices: [ServiceIdentifier]) {
        debugLog("SensorViewController - Invalidated services: \(invalidatedServices.debugDescription)")

        if invalidatedServices.contains(where: { invalidatedServiceIdentifier -> Bool in
            invalidatedServiceIdentifier == chirpCharacteristic.service
        }) {
            endListen(to: chirpCharacteristic)
        } else if invalidatedServices.isEmpty {
            listen(to: chirpCharacteristic)
        }
    }
}
