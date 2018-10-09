//
//  ScanAction.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-02-27.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation

/// Indicates whether a scan should continue, continue but blacklist the current discovery, stop, or stop and connect.
public enum ScanAction {
    /// Continue scanning.
    case `continue`
    /// Continue scanning, but don't discover the same peripheral in the current callback again within the same scan session.
    case blacklist
    /// Stop scanning.
    case stop
    /// Stop scanning, and connect to a discovery.
    case connect(ScanDiscovery, Timeout, WarningOptions, (ConnectionResult) -> Void)
}
