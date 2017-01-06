//
//  BluejayWriteResult.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-05.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation

/// Indicates a successful or failed write attempt.
public enum BluejayWriteResult {
    case success
    case failure(Error)
}
