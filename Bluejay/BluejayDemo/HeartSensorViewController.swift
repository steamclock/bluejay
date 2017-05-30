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
    
    @IBOutlet var connectCell: UITableViewCell!
    
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
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if let selectedCell = tableView.cellForRow(at: indexPath) {
            if selectedCell == connectCell {
                connect()
            }
        }
    }
    
}
