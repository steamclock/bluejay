//
//  BackgroundRestoreConfig.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2018-12-11.
//  Copyright © 2018 Steamclock Software. All rights reserved.
//

import Foundation
import UIKit

/// Contains all required configurations for background restoration.
public struct BackgroundRestoreConfig {
    /// A restore identifier helps uniquely identify which device is triggering background restoration.
    public let restoreIdentifier: RestoreIdentifier

    /// A background restorer is required to handle the results of a background restoration.
    public let backgroundRestorer: BackgroundRestorer

    /// A listen restorer is required for any potential unhandled listens when restoring to a connected peripheral.
    public let listenRestorer: ListenRestorer

    /// The launch options from `application(_:didFinishLaunchingWithOptions:)` is required to parse the restore identifier.
    public let launchOptions: LaunchOptions

    /// Convenience return of bluetooth central keys from the launch options.
    public var centralKeys: [String]? {
        return launchOptions?[UIApplication.LaunchOptionsKey.bluetoothCentrals] as? [String]
    }

    /// If CoreBluetooth is restoring from background, the bluetooth central keys from launch options will contain the designated restore identifier.
    public var isRestoringFromBackground: Bool {
        return centralKeys?.contains(restoreIdentifier) ?? false
    }

    /**
     * Initializes a container for all required configurations necessary to support background restoration.
     *
     * - Parameters:
     *    - restoreIdentifier: a restore identifier helps uniquely identify which device is triggering background restoration.
     *    - backgroundRestorer: a background restorer is required to handle the results of a background restoration.
     *    - listenRestorer: a listen restorer is required for any potential unhandled listens when restoring to a connected peripheral.
     *    - launchOptions: the launch options from `application(_:didFinishLaunchingWithOptions:)` is required to parse the restore identifier.
     */
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
