//
//  QueueableState.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-03.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation

/**
 Defines the possible states of a Queueable.
 */
enum QueueableState {
    
    case notStarted
    case running
    case cancelling
    case cancelled
    case failed(Error)
    case completed
    
    var isFinished: Bool {
        switch self {
        case .completed, .cancelled, .failed:
            return true
        default:
            return false
        }
    }
    
}
