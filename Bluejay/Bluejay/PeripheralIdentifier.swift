//
//  PeripheralIdentifier.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-03.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation

/**
    Uniquely identifies a peripheral to the current iOS device. The UUID changes and is different on different iOS devices.
*/
public struct PeripheralIdentifier {
    
    public private(set) var uuid: UUID
    
    public init?(uuid: String) {
        if let uuid = UUID(uuidString: uuid) {
            self.uuid = uuid
        }
        else {
            return nil
        }
    }
    
    public init(uuid: UUID) {
        self.uuid = uuid
    }
    
}
