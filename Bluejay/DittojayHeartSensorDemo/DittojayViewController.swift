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

    var addedServices: [CBService] = []

    var heartRate: UInt8 = 0

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

        wakeAppCharacteristic = CBMutableCharacteristic(
            type: wakeAppCharacteristicUUID,
            properties: .notify,
            value: nil,
            permissions: .readable)

        wakeAppService = CBMutableService(type: wakeAppServiceUUID, primary: true)
        wakeAppService.characteristics = [wakeAppCharacteristic]

        manager.add(wakeAppService)
    }

    private func advertiseServices(_ services: [CBUUID]) {
        manager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: services])
    }

    private func startHeartRateSensor() {
        _ = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
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
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "actionCell", for: indexPath)

        if indexPath.row == 0 {
            cell.textLabel?.text = "Generated Heart Rate"
            cell.detailTextLabel?.text = "\(heartRate)"

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

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        chirp()
    }
}

extension DittojayViewController: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        debugPrint("Did update state.")

        if peripheral.state == .poweredOn {
            addHeartRateService()
            addWakeAppService()
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error {
            debugPrint("Failed to add service \(service.uuid.uuidString) with error: \(error.localizedDescription)")
        } else {
            debugPrint("Added service \(service.uuid.uuidString)")

            addedServices.append(service)

            if addedServices.contains(heartRateService) && addedServices.contains(wakeAppService) {
                advertiseServices([heartRateService.uuid, wakeAppService.uuid])
                startHeartRateSensor()
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
}
