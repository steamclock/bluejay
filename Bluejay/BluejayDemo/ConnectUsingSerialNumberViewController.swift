//
//  ConnectUsingSerialNumberViewController.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-05-19.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import UIKit
import Bluejay

struct Services {
    static let deviceInfo = ServiceIdentifier(uuid: "D12F953F-18ED-45F8-BC0B-6B78DB90B491")
}

struct Charactersitics {
    static let serialNumber = CharacteristicIdentifier(uuid: "ED8C753F-C961-4861-A399-3B1568C1D23E", service: Services.deviceInfo)
}

class ConnectUsingSerialNumberViewController: UIViewController {
    
    @IBOutlet var statusLabel: UILabel!
    
    private let bluejay = Bluejay()
    
    private var blacklistedDiscoveries = [ScanDiscovery]()
    
    private var targetSerialNumber: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        statusLabel.text = "Waiting"
        
        bluejay.start()
        
        askForSerialNumber()
    }
    
    private func askForSerialNumber() {
        let alert = UIAlertController(
            title: "Enter Serial Number",
            message: "Please enter the serial number of the peripheral you wish to connect to.",
            preferredStyle: .alert
        )
        
        alert.addTextField { (textField) in
            textField.placeholder = "ASDF1234"
        }
        
        let connect = UIAlertAction(title: "Connect", style: .default) { [weak self] (action) in
            guard let weakSelf = self else {
                return
            }
            
            if let serialNumber = alert.textFields?.first?.text {
                if serialNumber.isEmpty {
                    weakSelf.askForSerialNumber()
                }
                else {
                    weakSelf.targetSerialNumber = serialNumber
                    weakSelf.scan(services: [Services.deviceInfo], serialNumber:serialNumber)
                }
            }
        }
        
        let cancel = UIAlertAction(title: "Cancel", style: .cancel) { [weak self] (action) in
            if let weakSelf = self {
                weakSelf.navigationController?.popViewController(animated: true)
            }
        }
        
        alert.addAction(connect)
        alert.addAction(cancel)
        
        navigationController?.present(alert, animated: true, completion: nil)
    }
    
    private func scan(services: [ServiceIdentifier], serialNumber: String) {
        debugPrint("Looking for peripheral with serial number \(serialNumber) to connect to.")
        
        statusLabel.text = "Searching..."
        
        bluejay.scan(
            allowDuplicates: false,
            serviceIdentifiers: services,
            discovery: { [weak self] (discovery, discoveries) -> ScanAction in
                guard let weakSelf = self else {
                    return .stop
                }
                
                if weakSelf.blacklistedDiscoveries.contains(where: { (blacklistedDiscovery) -> Bool in
                    return blacklistedDiscovery.peripheralIdentifier == discovery.peripheralIdentifier
                })
                {
                    return .blacklist
                }
                else {
                    return .connect(discovery, .none, { (connectionResult) in
                        switch connectionResult {
                        case .success(let peripheral):
                            debugPrint("Connection to \(peripheral.identifier) successful.")
                            
                            weakSelf.bluejay.read(from: Charactersitics.serialNumber, completion: { (readResult: ReadResult<String>) in
                                switch readResult {
                                case .success(let serialNumber):
                                    if serialNumber == weakSelf.targetSerialNumber {
                                        debugPrint("Serial number matched.")
                                        
                                        weakSelf.statusLabel.text = "Connected"
                                    }
                                    else {
                                        debugPrint("Serial number mismatch.")
                                        
                                        weakSelf.blacklistedDiscoveries.append(discovery)
                                        
                                        weakSelf.bluejay.disconnect(completion: { (result) in
                                            switch result {
                                            case .success:
                                                weakSelf.scan(services: [Services.deviceInfo], serialNumber: weakSelf.targetSerialNumber!)
                                            case .cancelled:
                                                preconditionFailure("Disconnect cancelled unexpectedly.")
                                            case .failure(let error):
                                                preconditionFailure("Disconnect failed with error: \(error.localizedDescription)")
                                            }
                                        })
                                    }
                                case .cancelled:
                                    debugPrint("Read serial number cancelled.")
                                    
                                    weakSelf.statusLabel.text = "Read Cancelled"
                                case .failure(let error):
                                    debugPrint("Read serial number failed with error: \(error.localizedDescription).")
                                    
                                    weakSelf.statusLabel.text = "Read Error: \(error.localizedDescription)"
                                }
                            })
                        case .cancelled:
                            debugPrint("Connection to \(discovery.peripheralIdentifier) cancelled.")
                            
                            weakSelf.statusLabel.text = "Connection Cancelled"
                        case .failure(let error):
                            debugPrint("Connection to \(discovery.peripheralIdentifier) failed with error: \(error.localizedDescription)")
                            
                            weakSelf.statusLabel.text = "Connection Error: \(error.localizedDescription)"
                        }
                    })
                }
            }) { [weak self] (discoveries, error) in
            guard let weakSelf = self else {
                return
            }
            
            if let error = error {
                debugPrint("Scan stopped with error: \(error.localizedDescription)")
                
                weakSelf.statusLabel.text = "Scan Error: \(error.localizedDescription)"
            }
            else {
                debugPrint("Scan stopped without error.")
            }
        }
    }
    
}
