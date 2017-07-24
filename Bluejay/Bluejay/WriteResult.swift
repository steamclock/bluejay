//
//  WriteResult.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-05.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation

/// Indicates a successful, cancelled, or failed write attempt.
public enum WriteResult {
    case success
    case cancelled
    case failure(Swift.Error)
}
