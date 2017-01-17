//
//  ReadResult.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-03.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation

/// Indicates a successful or failed read attempt, where the success case contains the value read.
public enum ReadResult<R> {
    case success(R)
    case failure(Swift.Error)
}

extension ReadResult where R: Receivable {
    
    /// Create a typed read result from raw data.
    init(dataResult: ReadResult<Data?>) {
        switch dataResult {
        case .failure(let error):
            self = .failure(error)
        case .success(let data):
            if let data = data {
                self = .success(R(bluetoothData: data))
            }
            else {
                self = .failure(Error.missingDataError())
            }
        }
    }
    
}
