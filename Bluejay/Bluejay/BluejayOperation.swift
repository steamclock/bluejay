//
//  BluejayOperation.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-03.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import CoreBluetooth

protocol BluejayOperation {
    
    var state: BluejayOperationState { get }
    
    func start(_ peripheral: CBPeripheral)
    func receivedEvent(_ event: BluejayEvent, peripheral: CBPeripheral)
    func fail(_ error: NSError)
    
}
