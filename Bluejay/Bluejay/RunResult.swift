//
//  RunResult.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-06-01.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation

public enum RunResult<R> {
    case success(R)
    case cancelled
    case failure(Swift.Error)
}

extension RunResult where R: Receivable {
    
    init(dataResult: RunResult<Data?>) {
        switch dataResult {
        case .success(let data):
            if let data = data {
                self = .success(R(bluetoothData: data))
            }
            else {
                self = .failure(Error.missingDataError())
            }
        case .cancelled:
            self = .cancelled
        case .failure(let error):
            self = .failure(error)
        }
    }
    
}
