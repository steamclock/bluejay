//
//  BackgroundRestoreConfig.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2018-12-11.
//  Copyright © 2018 Steamclock Software. All rights reserved.
//

import Foundation

/// Contains all required configurations for background restoration.
public struct BackgroundRestoreConfig {
    public let restoreIdentifier: RestoreIdentifier
    public let backgroundRestorer: BackgroundRestorer
    public let listenRestorer: ListenRestorer
    public let launchOptions: LaunchOptions

    /// Convenience return of bluetooth central keys from the launch options.
    public var centralKeys: [String]? {
        return launchOptions?[UIApplication.LaunchOptionsKey.bluetoothCentrals] as? [String]
    }

    /// If CoreBluetooth is restoring from background, the bluetooth central keys from launch options will contain the designated restore identifier.
    public var isRestoringFromBackground: Bool {
        return centralKeys?.contains(restoreIdentifier) ?? false
    }

    public init(
        restoreIdentifier: RestoreIdentifier,
        backgroundRestorer: BackgroundRestorer,
        listenRestorer: ListenRestorer,
        launchOptions: LaunchOptions) {
        self.restoreIdentifier = restoreIdentifier
        self.backgroundRestorer = backgroundRestorer
        self.listenRestorer = listenRestorer
        self.launchOptions = launchOptions
    }
}

/**
 * An alias to make it clearer that the string should be some kind of identifier for restoration, and not just any arbitrary string.
 *
 * - Note: Please provide a unique restore identifier for CoreBluetooth. See [Apple documentation](https://developer.apple.com/reference/corebluetooth/cbcentralmanageroptionrestoreidentifierkey) for more details.
 */
public typealias RestoreIdentifier = String

/// An alias to make it clearer that the dictionary should be the launch options from `UIApplicationDelegate`.
public typealias LaunchOptions = [UIApplication.LaunchOptionsKey: Any]?
