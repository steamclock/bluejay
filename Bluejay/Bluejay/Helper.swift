//
//  Helper.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-03.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation

/**
    A class containing a variety of useful and common static functions that don't belong anywhere else.
*/
public struct Helper {
    
    /**
        Helper function to take an array of sendable objects and merge their data together.
     
        - Parameter sendables: An array of BluejaySendable objects whose Data should be appended in the order of the array.
     
        - Returns: The data of all the BluejaySendable objects joined together in the order of the passed in array.
    */
    public static func join(sendables: [Sendable]) -> Data {
        let data = NSMutableData()
        
        for sendable in sendables {
            data.append(sendable.toBluetoothData())
        }
        
        return data as Data
    }
    
}
