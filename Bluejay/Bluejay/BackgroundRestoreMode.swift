//
//  BackgroundRestoreMode.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-06-01.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation

public enum BackgroundRestoreMode {
    case disable
    case enable(String)
    case enableWithListenRestorer(String, ListenRestorer)
}
