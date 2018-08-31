import Foundation
import CoreBluetooth

/// Allow configuring whether iOS can display a system alert when certain conditions are met while your app is suspended, usually an alert dialog outside of your app in the Home screen for example.
public enum ConnectionOption {

    /// Determines whether iOS should show a system alert when your suspended app is connected to a peripheral.
    case notifyOnConnection(enabled: Bool)
    
    /// Determines whether iOS should show a system alert when your suspended app is disconnected from a peripheral.
    case notifyOnDisconnection(enabled: Bool)
    
    /// Get key used by CoreBluetooth to set the initialization option.
    var option: [String : Bool] {
        switch self {
        case .notifyOnConnection(let enabled):
            return [CBConnectPeripheralOptionNotifyOnConnectionKey : enabled]
        case .notifyOnDisconnection(let enabled):
            return [CBConnectPeripheralOptionNotifyOnDisconnectionKey : enabled]
        }
    }
    
    /// Default configurations.
    public static var defaultOptions: [ConnectionOption] {
        return [.notifyOnConnection(enabled: true), .notifyOnDisconnection(enabled: true)]
    }
    
    /// Convenience helper to flatten the array of connection options into a dictionary for usage in CoreBluetooth.
    static func flatten(options: [ConnectionOption]) -> [String : Any] {
        let optionsArray = options.map { $0.option }
        let dictionary: [String : Any] = optionsArray.reduce([String : Any](), { result, next in
            result.merging(next) { (_, new) in new }
        })
        
        return dictionary
    }
    
}
