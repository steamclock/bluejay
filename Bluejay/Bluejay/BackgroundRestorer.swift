//
//  BackgroundRestorer.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2018-11-16.
//  Copyright © 2018 Steamclock Software. All rights reserved.
//

import Foundation

public typealias BackgroundRestoreCompletion = () -> Void

public protocol BackgroundRestorer: class {
    func didRestoreConnection(to peripheral: Peripheral) -> BackgroundRestoreCompletion
    func didFailToRestoreConnection(to peripheral: Peripheral, error: Error) -> BackgroundRestoreCompletion
}
