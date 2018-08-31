import Foundation
import CoreBluetooth

/// Allow configuring whether iOS can display a system alert when certain conditions are met while your app is suspended, usually an alert dialog outside of your app in the Home screen for example.
public struct ConnectionOptions {
    
    /// Determines whether iOS should show a system alert when your suspended app is connected to a peripheral.
    let notifyOnConnection: Bool
    
    /// Determines whether iOS should show a system alert when your suspended app is disconnected from a peripheral.
    let notifyOnDisconnection: Bool
    
    /// Default connection options.
    public static let defaultOptions = ConnectionOptions(notifyOnConnection: true, notifyOnDisconnection: true)
    
    /// Convenience helper to create a dictionary for usage in CoreBluetooth.
    var dictionary: [String : Bool] {
        return [CBConnectPeripheralOptionNotifyOnConnectionKey : notifyOnConnection, CBConnectPeripheralOptionNotifyOnDisconnectionKey : notifyOnDisconnection]
    }
    
    /**
     Creates a connection options that can specify whether iOS can display a system alert when certain conditions are met while your app is suspended, usually an alert dialog outside of your app in the Home screen for example.
     
     - Parameters:
         - notifyOnConnection: Determines whether iOS should show a system alert when your suspended app is connected to a peripheral.
         - notifyOnDisconnection: Determines whether iOS should show a system alert when your suspended app is disconnected from a peripheral.
     */
    public init(notifyOnConnection: Bool, notifyOnDisconnection: Bool) {
        self.notifyOnConnection = notifyOnConnection
        self.notifyOnDisconnection = notifyOnDisconnection
    }
    
}
