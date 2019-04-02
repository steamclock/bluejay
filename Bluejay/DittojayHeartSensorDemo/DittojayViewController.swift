//
//  DittojayViewController.swift
//  DittojayHeartSensorDemo
//
//  Created by Jeremy Chiang.
//  Copyright © 2019 Steamclock Software. All rights reserved.
//

import CoreBluetooth
import UIKit

class DittojayViewController: UITableViewController {

    var manager: CBPeripheralManager!

    var heartRateCharacteristic: CBMutableCharacteristic!
    var heartRateService: CBMutableService!

    var wakeAppCharacteristic: CBMutableCharacteristic!
    var wakeAppService: CBMutableService!

    var pairingCharacteristic: CBMutableCharacteristic!
    var pairingService: CBMutableService!

    var addedServices: [CBService] = []

    var heartRate: UInt8 = 0
    var timer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        manager = CBPeripheralManager(delegate: self, queue: DispatchQueue.main, options: nil)
    }

    private func addHeartRateService() {
        let heartRateServiceUUID = CBUUID(string: "180D")
        let heartRateCharacteristicUUID = CBUUID(string: "2A37")

        heartRateCharacteristic = CBMutableCharacteristic(
            type: heartRateCharacteristicUUID,
            properties: .notify,
            value: nil,
            permissions: .readable)

        heartRateService = CBMutableService(type: heartRateServiceUUID, primary: true)
        heartRateService.characteristics = [heartRateCharacteristic]

        manager.add(heartRateService)
    }

    private func addWakeAppService() {
        let wakeAppServiceUUID = CBUUID(string: "CED261B7-F120-41C8-9A92-A41DE69CF2A8")
        let wakeAppCharacteristicUUID = CBUUID(string: "83B4A431-A6F1-4540-B3EE-3C14AEF71A04")

        if addedServices.contains(where: { addedService -> Bool in
            addedService.uuid == wakeAppServiceUUID
        }) {
            return
        }

        wakeAppCharacteristic = CBMutableCharacteristic(
            type: wakeAppCharacteristicUUID,
            properties: .notify,
            value: nil,
            permissions: .readable)

        wakeAppService = CBMutableService(type: wakeAppServiceUUID, primary: true)
        wakeAppService.characteristics = [wakeAppCharacteristic]

        debugPrint("Will add wake app service...")

        manager.add(wakeAppService)
    }

    private func removeWakeAppService() {
        addedServices.removeAll { addedService -> Bool in
            addedService.uuid == wakeAppService.uuid
        }

        debugPrint("Will remove wake app service...")

        manager.remove(wakeAppService)

        if manager.isAdvertising {
            debugPrint("Will stop advertising...")
            manager.stopAdvertising()
        }

        debugPrint("Will start advertising...")
        advertiseServices([heartRateService.uuid])
    }

    private func addPairingService() {
        let pairingServiceUUID = CBUUID(string: "16274BFE-C539-416C-9646-CA3F991DADD6")
        let pairingCharacteristicUUID = CBUUID(string: "E4D4A76C-B9F1-422F-8BBA-18508356A145")

        if addedServices.contains(where: { addedService -> Bool in
            addedService.uuid == pairingServiceUUID
        }) {
            return
        }

        pairingCharacteristic = CBMutableCharacteristic(
            type: pairingCharacteristicUUID,
            properties: .read,
            value: "Steamclock Software".data(using: .utf8),
            permissions: .readEncryptionRequired
        )

        pairingService = CBMutableService(type: pairingServiceUUID, primary: true)
        pairingService.characteristics = [pairingCharacteristic]

        debugPrint("Will add pairing service...")

        manager.add(pairingService)
    }

    private func advertiseServices(_ services: [CBUUID]) {
        manager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: services])
    }

    private func startHeartRateSensor() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let weakSelf = self else {
                return
            }

            let heartRate = UInt8(arc4random_uniform(60) + 60) // 60bpm ~ 120bpm
            let heartRateData = HeartRateMeasurement(heartRate: heartRate)

            _ = weakSelf.manager.updateValue(
                heartRateData.toBluetoothData(),
                for: weakSelf.heartRateCharacteristic,
                onSubscribedCentrals: nil)

            DispatchQueue.main.async {
                weakSelf.heartRate = heartRate
                weakSelf.tableView.reloadData()
            }
        }
    }

    private func chirp() {
        _ = manager.updateValue(
            Data(),
            for: wakeAppCharacteristic,
            onSubscribedCentrals: nil)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "actionCell", for: indexPath)

        if indexPath.section == 0 {
            if indexPath.row == 0 {
                cell.textLabel?.text = "Generated Heart Rate"
                cell.detailTextLabel?.text = "\(heartRate)"
                cell.selectionStyle = .none

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
            } else {
                cell.textLabel?.text = "Chirp"
                cell.detailTextLabel?.text = ""
            }
        } else {
            if indexPath.row == 0 {
                cell.textLabel?.text = "Add Chirp Service"
                cell.detailTextLabel?.text = ""
            } else {
                cell.textLabel?.text = "Remove Chirp Service"
                cell.detailTextLabel?.text = ""
            }
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.section == 0 {
            if indexPath.row == 1 {
                chirp()
            }
        } else {
            if indexPath.row == 0 {
                addWakeAppService()
            } else {
                removeWakeAppService()
            }
        }
    }
}

extension DittojayViewController: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        debugPrint("Did update state.")

        if peripheral.state == .poweredOn {
            addHeartRateService()
            addWakeAppService()
            addPairingService()
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error {
            debugPrint("Failed to add service \(service.uuid.uuidString) with error: \(error.localizedDescription)")
        } else {
            if !addedServices.contains { addedService -> Bool in
                addedService.uuid == service.uuid
            } {
                debugPrint("Added service \(service.uuid.uuidString)")
                addedServices.append(service)
            }

            if addedServices.contains(heartRateService) && addedServices.contains(wakeAppService) {
                if manager.isAdvertising {
                    debugPrint("Will stop advertising...")
                    manager.stopAdvertising()
                }

                debugPrint("Will start advertising...")
                advertiseServices([heartRateService.uuid, wakeAppService.uuid])

                if timer == nil {
                    debugPrint("Will start heart rate sensor...")
                    startHeartRateSensor()
                }
            }
        }
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            debugPrint("Failed to start advertising with error: \(error.localizedDescription)")
        } else {
            debugPrint("Started advertising")
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        debugPrint("Did subscribe to: \(characteristic.uuid.uuidString)")
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        debugPrint("Did unsubscribe from: \(characteristic.uuid.uuidString)")
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        debugPrint("Did receive read request for: \(request.characteristic.uuid.uuidString)")
        if request.characteristic.uuid == pairingCharacteristic.uuid {
            peripheral.respond(to: request, withResult: .success)
        }
    }
}
