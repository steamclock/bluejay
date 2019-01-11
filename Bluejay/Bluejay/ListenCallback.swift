//
//  ListenCallback.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2018-12-06.
//  Copyright © 2018 Steamclock Software. All rights reserved.
//

import Foundation

/// Gives name to a specific callback type used for listens.
public typealias ListenCallback = (ReadResult<Data?>) -> Void
