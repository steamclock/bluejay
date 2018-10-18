//
//  RunResult.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-06-01.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation

/// Indicates a successful, cancelled, or failed `run(backgroundTask:completionOnMainThread:)` attempt, where the success case contains the value returned at the end of the background task.
public enum RunResult<R> {
    /// The background task is successful, and the returned value is captured in the associated value.
    case success(R)
    /// The background task has failed unexpectedly with an error.
    case failure(Error)
}
