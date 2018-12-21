//
//  AppDelegate.swift
//  BluejayHeartSensorDemo
//
//  Created by Jeremy Chiang on 2018-12-13.
//  Copyright © 2018 Steamclock Software. All rights reserved.
//

import Bluejay
import UIKit

let bluejay = Bluejay()

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        let backgroundRestoreConfig = BackgroundRestoreConfig(
            restoreIdentifier: "com.steamclock.bluejayHeartSensorDemo",
            backgroundRestorer: self,
            listenRestorer: self,
            launchOptions: launchOptions)

        let backgroundRestoreMode = BackgroundRestoreMode.enable(backgroundRestoreConfig)

        let options = StartOptions(enableBluetoothAlert: true, backgroundRestore: backgroundRestoreMode)

        bluejay.start(mode: .new(options))

        return true
    }

}

extension AppDelegate: BackgroundRestorer {
    func didRestoreConnection(to peripheral: PeripheralIdentifier) -> BackgroundRestoreCompletion {
        return .continue
    }

    func didFailToRestoreConnection(to peripheral: PeripheralIdentifier, error: Error) -> BackgroundRestoreCompletion {
        return .continue
    }
}

extension AppDelegate: ListenRestorer {
    func didReceiveUnhandledListen(from peripheral: PeripheralIdentifier, on characteristic: CharacteristicIdentifier, with value: Data?) -> ListenRestoreAction {
        return .promiseRestoration
    }
}
