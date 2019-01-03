//
//  MultipleListenOption.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2018-12-03.
//  Copyright © 2018 Steamclock Software. All rights reserved.
//

import Foundation

/// Ways to handle calling listen on the same characteristic multiple times.
public enum MultipleListenOption: Int {
    /// New listen and its new callback on the same characteristic will not overwrite an existing listen.
    case trap
    /// New listens and its new callback on the same characteristic will replace the existing listen.
    case replaceable
}
