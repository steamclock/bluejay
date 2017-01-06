//
//  BluejayHelper.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-03.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation

public struct BluejayHelper {
    
    /// Helper function to take an array of sendable objects and merge their data together.
    public static func joinSendables(_ elements: [BluejaySendable]) -> Data {
        let data = NSMutableData()
        
        for element in elements {
            data.append(element.toBluetoothData())
        }
        
        return data as Data
    }
    
}
