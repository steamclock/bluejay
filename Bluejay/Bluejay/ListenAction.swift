//
//  ListenAction.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-05.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation

/// Indicates whether the current listening on a characteristic should continue or end.
public enum ListenAction {
    case keepListening
    case done
}
