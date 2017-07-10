//
//  SensorLocationViewController.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-07-10.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import UIKit
import Bluejay

class SensorLocationViewController: UITableViewController {
    
    weak var bluejay: Bluejay?
    var sensorLocation: UInt8?
    
    private var selectedCell: UITableViewCell?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let sensorLocation = sensorLocation {
            let cell = super.tableView(tableView, cellForRowAt: IndexPath(row: Int(sensorLocation), section: 0))
            cell.accessoryType = .checkmark
            
            selectedCell = cell
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let heartRateService = ServiceIdentifier(uuid: "180D")
        let sensorLocation = CharacteristicIdentifier(uuid: "2A38", service: heartRateService)
        
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        
        bluejay?.write(to: sensorLocation, value: UInt8(indexPath.row), completion: { [weak self] (result) in
            guard let weakSelf = self else {
                return
            }
            
            switch result {
            case .success:
                debugPrint("Write to sensor location successful.")
                
                if let selectedCell = weakSelf.selectedCell {
                    selectedCell.accessoryType = .none
                }
                cell.accessoryType = .checkmark
                                
                weakSelf.navigationController?.popViewController(animated: true)
            case .cancelled:
                debugPrint("Write to sensor location cancelled.")
            case .failure(let error):
                debugPrint("Failed write to sensor location with error: \(error.localizedDescription)")
            }
        })
    }
}
