//
//  HeartSensorViewController.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-05-29.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Bluejay
import UIKit

class HeartSensorViewController: UITableViewController {

    weak var bluejay: Bluejay?
    var peripheralIdentifier: PeripheralIdentifier?

    @IBOutlet private var statusCell: UITableViewCell!
    @IBOutlet private var bpmCell: UITableViewCell!
    @IBOutlet private var sensorLocationCell: UITableViewCell!
    @IBOutlet private var connectCell: UITableViewCell!
    @IBOutlet private var disconnectCell: UITableViewCell!
    @IBOutlet private var startMonitoringCell: UITableViewCell!
    @IBOutlet private var resetCell: UITableViewCell!
    @IBOutlet private var cancelEverythingCell: UITableViewCell!

    private var isMonitoringHeartRate = false

    private var shouldRefreshSensorLocation = false
    private var sensorLocation: UInt8?

    override func viewDidLoad() {
        super.viewDidLoad()

        statusCell.detailTextLabel?.text = "Disconnected"
        bpmCell.detailTextLabel?.text = "0"
        sensorLocationCell.detailTextLabel?.text = "Unknown"

        guard let bluejay = bluejay else {
            showBluejayMissingAlert()
            return
        }

        bluejay.register(observer: self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if shouldRefreshSensorLocation {
            startMonitoringHeartRate()
            readSensorLocation()
        }
    }

    private func showBluejayMissingAlert() {
        let alert = UIAlertController(title: "Bluejay Error", message: "Bluejay is missing.", preferredStyle: .alert)
        let dismiss = UIAlertAction(title: "Dismiss", style: .default, handler: nil)

        alert.addAction(dismiss)

        navigationController?.present(alert, animated: true, completion: nil)
    }

    private func readSensorLocation() {
        guard let bluejay = bluejay else {
            showBluejayMissingAlert()
            return
        }

        let heartRateService = ServiceIdentifier(uuid: "180D")
        let sensorLocation = CharacteristicIdentifier(uuid: "2A38", service: heartRateService)

        bluejay.read(from: sensorLocation) { [weak self] (result: ReadResult<UInt8>) in
            guard let weakSelf = self else {
                return
            }

            switch result {
            case .success(let location):
                debugPrint("Sensor location read: \(location)")
                weakSelf.updateSensorLocationLabel(value: location)
            case .failure(let error):
                debugPrint("Failed to read sensor location with error: \(error.localizedDescription)")
            }
        }

        shouldRefreshSensorLocation = false
    }

    private func updateSensorLocationLabel(value: UInt8) {
        var locationString = "Unknown"

        switch value {
        case 0:
            locationString = "Other"
        case 1:
            locationString = "Chest"
        case 2:
            locationString = "Wrist"
        case 3:
            locationString = "Finger"
        case 4:
            locationString = "Hand"
        case 5:
            locationString = "Ear Lobe"
        case 6:
            locationString = "Foot"
        default:
            locationString = "Unknown"
        }

        sensorLocationCell.detailTextLabel?.text = locationString
        sensorLocation = value
    }

    private func startMonitoringHeartRate() {
        if isMonitoringHeartRate {
            return
        }

        guard let bluejay = bluejay else {
            showBluejayMissingAlert()
            return
        }

        let heartRateService = ServiceIdentifier(uuid: "180D")
        let heartRateCharacteristic = CharacteristicIdentifier(uuid: "2A37", service: heartRateService)

        var triedThirdListen = false

        bluejay.listen(to: heartRateCharacteristic, multipleListenOption: .replaceable) { [weak self] (result: ReadResult<HeartRateMeasurement>) in
            guard let weakSelf = self else {
                return
            }

            switch result {
            case .success(let heartRateMeasurement):
                debugPrint(heartRateMeasurement.measurement)
                weakSelf.isMonitoringHeartRate = true
                weakSelf.bpmCell.detailTextLabel?.text = "\(heartRateMeasurement.measurement)"

                DispatchQueue.main.async {
                    UIView.animate(withDuration: 0.25, animations: {
                        weakSelf.bpmCell.detailTextLabel?.transform = weakSelf.bpmCell.detailTextLabel!.transform.scaledBy(x: 1.5, y: 1.5)
                    }, completion: { completed in
                        if completed {
                            UIView.animate(withDuration: 0.25, animations: {
                                weakSelf.bpmCell.detailTextLabel?.transform = CGAffineTransform.identity
                            })
                        }
                    })
                }

                if !triedThirdListen {
                    triedThirdListen = true
                    bluejay.listen(to: heartRateCharacteristic) { (result: ReadResult<HeartRateMeasurement>) in
                        switch result {
                        case .success(let heartRateMeasurement):
                            debugPrint("Third listen: \(heartRateMeasurement.measurement)")
                        case .failure(let error):
                            debugPrint("Failed to third listen to heart rate measurement with error: \(error.localizedDescription)")
                        }
                    }
                }
            case .failure(let error):
                debugPrint("Failed to listen to heart rate measurement with error: \(error.localizedDescription)")
                weakSelf.isMonitoringHeartRate = false

                if !triedThirdListen {
                    triedThirdListen = true
                    bluejay.listen(to: heartRateCharacteristic) { (result: ReadResult<HeartRateMeasurement>) in
                        switch result {
                        case .success(let heartRateMeasurement):
                            debugPrint("Third listen: \(heartRateMeasurement.measurement)")
                        case .failure(let error):
                            debugPrint("Failed to third listen to heart rate measurement with error: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }

        bluejay.listen(to: heartRateCharacteristic) { (result: ReadResult<HeartRateMeasurement>) in
            switch result {
            case .success(let heartRateMeasurement):
                debugPrint("Duplicated listen: \(heartRateMeasurement.measurement)")
            case .failure(let error):
                debugPrint("Failed to duplicate listen to heart rate measurement with error: \(error.localizedDescription)")
            }
        }
    }

    private func stopMonitoringHeartRate() {
        guard let bluejay = bluejay else {
            showBluejayMissingAlert()
            return
        }

        let heartRateService = ServiceIdentifier(uuid: "180D")
        let heartRateMeasurement = CharacteristicIdentifier(uuid: "2A37", service: heartRateService)

        bluejay.endListen(to: heartRateMeasurement)
    }

    private func connect() {
        guard let bluejay = bluejay else {
            showBluejayMissingAlert()
            return
        }

        guard let peripheralIdentifier = peripheralIdentifier else {
            debugPrint("Cannot connect: peripheral identifier is missing.")
            return
        }

        bluejay.connect(peripheralIdentifier, timeout: .none) { result in
            switch result {
            case .success(let peripheral):
                debugPrint("Connection to \(peripheral.name) successful.")
            case .failure(let error):
                debugPrint("Connection to \(peripheralIdentifier.uuid.uuidString) failed with error: \(error.localizedDescription)")
            }
        }
    }

    private func disconnect() {
        guard let bluejay = bluejay else {
            showBluejayMissingAlert()
            return
        }

        guard let peripheralIdentifier = peripheralIdentifier else {
            debugPrint("Cannot connect: peripheral identifier is missing.")
            return
        }

        bluejay.disconnect { result in
            switch result {
            case .disconnected(let peripheral):
                debugPrint("Disconnect from \(peripheral.name) successful.")
            case .failure(let error):
                debugPrint("Disconnect from \(peripheralIdentifier.uuid.uuidString) failed with error: \(error.localizedDescription)")
            }
        }
    }

    private func reset() {
        guard let bluejay = bluejay else {
            showBluejayMissingAlert()
            return
        }

        let heartRateService = ServiceIdentifier(uuid: "180D")
        let heartRateMeasurement = CharacteristicIdentifier(uuid: "2A37", service: heartRateService)
        let sensorLocation = CharacteristicIdentifier(uuid: "2A38", service: heartRateService)

        bluejay.run(backgroundTask: { peripheral -> UInt8 in
            // 1. Stop monitoring.
            debugPrint("Reset step 1: stop monitoring.")
            try peripheral.endListen(to: heartRateMeasurement)

            // 2. Set sensor location to 0.
            debugPrint("Reset step 2: set sensor location to 0.")
            try peripheral.write(to: sensorLocation, value: UInt8(0))

            // 3. Read sensor location.
            debugPrint("Reset step 3: read sensor location.")
            let sensorLocation = try peripheral.read(from: sensorLocation) as UInt8

            /*
             Don't use the listen from the synchronized peripheral here to start monitoring the heart rate again, as it will actually block until it is turned off. The synchronous listen is for when you want to listen to and process some expected incoming values before moving on to the next steps in your background task. It is different from the regular asynchronous listen that is more commonly used for continuous monitoring.
             */

            // 4. Return the data of interest and process it in the completion block on the main thread.
            debugPrint("Reset step 4: return sensor location.")
            return sensorLocation
        }, completionOnMainThread: { [weak self] (result: RunResult<UInt8>) in
            guard let weakSelf = self else {
                return
            }

            switch result {
            case .success(let sensorLocation):
                // Update the sensor location label on the main thread.
                weakSelf.updateSensorLocationLabel(value: sensorLocation)

                // Resume monitoring. Now we can use the non-blocking listen from Bluejay, not from the SynchronizedPeripheral.
                weakSelf.startMonitoringHeartRate()
            case .failure(let error):
                debugPrint("Failed to complete reset background task with error: \(error.localizedDescription)")
            }
        })
    }

    private func cancelEverything() {
        guard let bluejay = bluejay else {
            showBluejayMissingAlert()
            return
        }

        bluejay.cancelEverything()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if let selectedCell = tableView.cellForRow(at: indexPath) {
            if selectedCell == sensorLocationCell {
                shouldRefreshSensorLocation = true
                performSegue(withIdentifier: "showSensorLocation", sender: self)
            } else if selectedCell == connectCell {
                connect()
            } else if selectedCell == disconnectCell {
                disconnect()
            } else if selectedCell == startMonitoringCell {
                startMonitoringHeartRate()
            } else if selectedCell == resetCell {
                reset()
            } else if selectedCell == cancelEverythingCell {
                cancelEverything()
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showSensorLocation" {
            if let sensorLocationViewController = segue.destination as? SensorLocationViewController {
                sensorLocationViewController.bluejay = bluejay
                sensorLocationViewController.sensorLocation = sensorLocation
            }
        }
    }

}

extension HeartSensorViewController: ConnectionObserver {

    func connected(to peripheral: Peripheral) {
        statusCell.detailTextLabel?.text = "Connected"

        startMonitoringHeartRate()
        readSensorLocation()
    }

    func disconnected(from peripheral: Peripheral) {
        isMonitoringHeartRate = false

        statusCell.detailTextLabel?.text = "Disconnected"
        bpmCell.detailTextLabel?.text = "0"
        sensorLocationCell.detailTextLabel?.text = "Unknown"
    }

    func bluetoothAvailable(_ available: Bool) {
        if !available {
            isMonitoringHeartRate = false

            statusCell.detailTextLabel?.text = "Disconnected"
            bpmCell.detailTextLabel?.text = "0"
            sensorLocationCell.detailTextLabel?.text = "Unknown"
        }
    }

}
