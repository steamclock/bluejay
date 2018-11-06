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
    case stopping(Error)
    case failed(Error)
    case completed

    var isFinished: Bool {
        switch self {
        case .failed, .completed:
            return true
        default:
            return false
        }
    }

    var description: String {
        switch self {
        case .notStarted:
            return "Not started"
        case .running:
            return "Running"
        case .stopping(let error):
            return "Stopping with error: \(error.localizedDescription)"
        case .failed(let error):
            return "Failed with error: \(error.localizedDescription)"
        case .completed:
            return "Completed"
        }
    }

}
