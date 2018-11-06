//
//  String+Transferable.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-02-09.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation

/// Make String Sendable and Receivable.
extension String {

    public init(bluetoothData: Data) {
        self = String(data: bluetoothData, encoding: .utf8)!
    }

    public func toBluetoothData() -> Data {
        return self.data(using: .utf8)!
    }

}

extension String: Sendable, Receivable {}
