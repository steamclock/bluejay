//
//  BluejayReadResult.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-03.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation

/// Indicates a successful or failed read attempt, where the success case contains the value read.
public enum BluejayReadResult<R> {
    case success(R)
    case failure(Error)
}

extension BluejayReadResult where R: BluejayReceivable {
    
    /// Create a typed read result from raw data.
    init(dataResult: BluejayReadResult<Data?>) {
        switch dataResult {
        case .failure(let error):
            self = .failure(error)
        case .success(let data):
            if let data = data {
                self = .success(R(bluetoothData: data))
            }
            else {
                self = .failure(BluejayErrors.missingDataError())
            }
        }
    }
    
}
