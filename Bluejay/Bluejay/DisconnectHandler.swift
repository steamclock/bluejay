//
//  DisconnectHandler.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2018-10-11.
//  Copyright © 2018 Steamclock Software. All rights reserved.
//

import Foundation

public protocol DisconnectHandler: class {
    func didDisconnect(from peripheral: Peripheral, with error: Error?, willReconnect autoReconnect: Bool) -> AutoReconnectMode
}

public enum AutoReconnectMode {
    case noChange
    case change(shouldAutoReconnect: Bool)
}

struct WeakDisconnectHandler {
    weak var weakReference: DisconnectHandler?
}
