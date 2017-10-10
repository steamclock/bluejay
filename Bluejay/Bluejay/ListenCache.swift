//
//  ListenCache.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-04-28.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation

/// The `ListenCache` is used to store the service and characteristic UUID of a listen that needs to be restored in the event of a state restoration. It can also serialize and deserialize the model into and back from Data, so that it can be stored and retrieved from UserDefaults.
struct ListenCache: Codable {
    let serviceUUID: String
    let characteristicUUID: String
}
