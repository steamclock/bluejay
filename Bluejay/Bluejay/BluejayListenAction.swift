//
//  BluejayListenAction.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-05.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation

/// Indicates whether the current listening action on a characteristic should continue or end.
public enum BluejayListenAction {
    case keepListening
    case done
}
