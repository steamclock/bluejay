//
//  HeartSensorViewController.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-05-29.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import UIKit
import Bluejay
import CoreBluetooth

class HeartSensorViewController: UITableViewController {
    
    weak var bluejay: Bluejay?
    var peripheralIdentifier: PeripheralIdentifier?
    
    @IBOutlet var statusCell: UITableViewCell!
    @IBOutlet var bpmCell: UITableViewCell!
    @IBOutlet var connectCell: UITableViewCell!
    @IBOutlet var disconnectCell: UITableViewCell!
    
    fileprivate var isMonitoringHeartRate = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        statusCell.detailTextLabel?.text = ""
        bpmCell.detailTextLabel?.text = "0"
        
        guard let bluejay = bluejay else {
            showBluejayMissingAlert()
            return
        }
        
        bluejay.register(observer: self)
    }
    
    fileprivate func showBluejayMissingAlert() {
        let alert = UIAlertController(title: "Bluejay Error", message: "Bluejay is missing.", preferredStyle: .alert)
        let dismiss = UIAlertAction(title: "Dismiss", style: .default, handler: nil)
        
        alert.addAction(dismiss)
        
        navigationController?.present(alert, animated: true, completion: nil)
    }
    
    fileprivate func startMonitoringHeartRate() {
        if isMonitoringHeartRate {
            return
        }
        
        guard let bluejay = bluejay else {
            showBluejayMissingAlert()
            return
        }
        
        let heartRateService = ServiceIdentifier(uuid: "180D")
        let heartRateMeasurement = CharacteristicIdentifier(uuid: "2A37", service: heartRateService)
        
        bluejay.listen(to: heartRateMeasurement) { [weak self] (result: ReadResult<HeartRateMeasurement>) in
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
                    }, completion: { (completed) in
                        if completed {
                            UIView.animate(withDuration: 0.25, animations: {
                                weakSelf.bpmCell.detailTextLabel?.transform = CGAffineTransform.identity
                            })
                        }
                    })
                }
            case .cancelled:
                debugPrint("Cancelled")
                weakSelf.isMonitoringHeartRate = false
            case .failure(let error):
                debugPrint("Failed to listen to heart rate measurement with error: \(error.localizedDescription)")
                weakSelf.isMonitoringHeartRate = false
            }
        }
    }
        
    private func connect() {
        guard let bluejay = bluejay else {
            debugPrint("Cannot connect: bluejay is missing.")
            return
        }
        
        guard let peripheralIdentifier = peripheralIdentifier else {
            debugPrint("Cannot connect: peripheral identifier is missing.")
            return
        }
        
        bluejay.connect(peripheralIdentifier) { (result) in
            switch result {
            case .success(let peripheral):
                debugPrint("Connection to \(peripheral.identifier) successful.")
            case .cancelled:
                debugPrint("Connection to \(peripheralIdentifier.uuid.uuidString) cancelled.")
            case .failure(let error):
                debugPrint("Connection to \(peripheralIdentifier.uuid.uuidString) failed with error: \(error.localizedDescription)")
            }
        }
    }
    
    private func disconnect() {
        guard let bluejay = bluejay else {
            debugPrint("Cannot connect: bluejay is missing.")
            return
        }
        
        guard let peripheralIdentifier = peripheralIdentifier else {
            debugPrint("Cannot connect: peripheral identifier is missing.")
            return
        }
        
        bluejay.disconnect { (result) in
            switch result {
            case .success(let peripheral):
                debugPrint("Disconnection from \(peripheral.identifier) successful.")
            case .cancelled:
                debugPrint("Disconnection from \(peripheralIdentifier.uuid.uuidString) cancelled.")
            case .failure(let error):
                debugPrint("Disconnection from \(peripheralIdentifier.uuid.uuidString) failed with error: \(error.localizedDescription)")
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if let selectedCell = tableView.cellForRow(at: indexPath) {
            if selectedCell == connectCell {
                connect()
            }
            else if selectedCell == disconnectCell {
                disconnect()
            }
        }
    }
    
}

extension HeartSensorViewController: ConnectionObserver {
    
    func connected(to peripheral: Peripheral) {
        statusCell.detailTextLabel?.text = "Connected"
        
        startMonitoringHeartRate()
    }
    
    func disconnected() {
        isMonitoringHeartRate = false

        statusCell.detailTextLabel?.text = "Disconnected"
        bpmCell.detailTextLabel?.text = "0"
        
        guard let bluejay = bluejay else {
            showBluejayMissingAlert()
            return
        }
        
        let heartRateService = ServiceIdentifier(uuid: "180D")
        let heartRateMeasurement = CharacteristicIdentifier(uuid: "2A37", service: heartRateService)
        
        bluejay.endListen(to: heartRateMeasurement)
    }
    
}
