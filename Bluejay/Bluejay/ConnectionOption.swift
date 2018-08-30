import Foundation
import CoreBluetooth

public enum ConnectionOption {

    /// Wether the os should notify the user on connection (referres to the CoreBluetooth key CBConnectPeripheralOptionNotifyOnConnectionKey)
    case notifyOnConnection
    /// Wether the os should notify the user on disconnection (referres to the CoreBluetooth key CBConnectPeripheralOptionNotifyOnDisconnectionKey)
    case notifyOnDisconnection
    /// Wether the os should display an alert if bluetooth is turned off during initialization of a CBCentralManager (refferes to the CoreBluetooth key CBCentralManagerOptionShowPowerAlertKey)
    case showPowerAlert

    /// Get key used by CoreBluetooth to set the initialization option
    var coreBluetoothKey: String {
        switch self {
        case .notifyOnConnection:
            return CBConnectPeripheralOptionNotifyOnConnectionKey
        case .notifyOnDisconnection:
            return CBConnectPeripheralOptionNotifyOnDisconnectionKey
        case .showPowerAlert:
            return CBCentralManagerOptionShowPowerAlertKey
        }
    }
}
