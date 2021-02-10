//
//  AppDelegate.swift
//  BluejayHeartSensorDemo
//
//  Created by Jeremy Chiang on 2018-12-13.
//  Copyright © 2018 Steamclock Software. All rights reserved.
//

import Bluejay
import UIKit
import UserNotifications

let bluejay = Bluejay()

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        let center = UNUserNotificationCenter.current()
        // Request permission to display alerts and play sounds.
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                debugLog("User notifications authorization granted")
            } else if let error = error {
                debugLog("User notifications authorization error: \(error.localizedDescription)")
            }
        }

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
        let content = UNMutableNotificationContent()
        content.title = "Bluejay Heart Sensor"
        content.body = "Did restore connection."

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)

        return .continue
    }

    func didFailToRestoreConnection(to peripheral: PeripheralIdentifier, error: Error) -> BackgroundRestoreCompletion {
        let content = UNMutableNotificationContent()
        content.title = "Bluejay Heart Sensor"
        content.body = "Did fail to restore connection."

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)

        return .continue
    }
}

extension AppDelegate: ListenRestorer {
    func didReceiveUnhandledListen(from peripheral: PeripheralIdentifier, on characteristic: CharacteristicIdentifier, with value: Data?) -> ListenRestoreAction {
        let content = UNMutableNotificationContent()
        content.title = "Bluejay Heart Sensor"
        content.body = "Did receive unhandled listen."

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)

        return .promiseRestoration
    }
}
