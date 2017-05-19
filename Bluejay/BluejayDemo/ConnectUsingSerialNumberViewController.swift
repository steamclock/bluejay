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
    
    private let bluejay = Bluejay()
    
    private var blacklistedDiscoveries = [ScanDiscovery]()
    
    private let targetSerialNumber = "ASDF1234"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        bluejay.start()
        
        scan(services: [Services.deviceInfo])
    }
    
    private func scan(services: [ServiceIdentifier]) {
        bluejay.scan(
            allowDuplicates: false,
            serviceIdentifiers: services,
            discovery: { [weak self] (discovery, discoveries) -> ScanAction in
                guard let weakSelf = self else {
                    return .stop
                }
                
                if weakSelf.blacklistedDiscoveries.contains(where: { (blacklistedDiscovery) -> Bool in
                    return blacklistedDiscovery.peripheral.identifier == discovery.peripheral.identifier
                })
                {
                    return .blacklist
                }
                else {
                    return .connect(discovery, { (connectionResult) in
                        switch connectionResult {
                        case .success(let peripheral):
                            debugPrint("Connection to \(peripheral.identifier) successful.")
                            
                            weakSelf.bluejay.read(from: Charactersitics.serialNumber, completion: { (readResult: ReadResult<String>) in
                                switch readResult {
                                case .success(let serialNumber):
                                    if serialNumber == weakSelf.targetSerialNumber {
                                        debugPrint("Serial number matched.")
                                    }
                                    else {
                                        debugPrint("Serial number mismatch.")
                                        
                                        weakSelf.blacklistedDiscoveries.append(discovery)
                                        
                                        weakSelf.bluejay.disconnect(completion: { (isSuccessful) in
                                            precondition(isSuccessful, "Disconnection from \(discovery.peripheral.identifier) failed.")
                                            
                                            weakSelf.scan(services: [Services.deviceInfo])
                                        })
                                    }
                                case .cancelled:
                                    debugPrint("Read serial number cancelled.")
                                case .failure(let error):
                                    debugPrint("Read serial number failed with error: \(error.localizedDescription).")
                                }
                            })
                        case .cancelled:
                            debugPrint("Connection to \(discovery.peripheral.identifier) cancelled.")
                        case .failure(let error):
                            debugPrint("Connection to \(discovery.peripheral.identifier) failed with error: \(error.localizedDescription)")
                        }
                    })
                }
            },
            expired: { [weak self] (lostDiscovery, discoveries) -> ScanAction in
                guard let weakSelf = self else {
                    return .stop
                }
                
                debugPrint("Lost discovery: \(lostDiscovery)")
                
                return .continue
        }) { (discoveries, error) in
            if let error = error {
                debugPrint("Scan stopped with error: \(error.localizedDescription)")
            }
            else {
                debugPrint("Scan stopped without error.")
            }
        }
    }
    
}
