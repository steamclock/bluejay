//
//  ServiceIdentifier.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-03.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import CoreBluetooth

/// A wrapper for CBUUID specific to a service to help distinguish it from a CBUUID of a charactersitc.
public struct ServiceIdentifier {
    
    public private(set) var uuid: CBUUID
    
    public init(uuid: String) {
        self.uuid = CBUUID(string: uuid)
    }
    
    public init(_ uuid: CBUUID) {
        self.uuid = uuid
    }
    
}
