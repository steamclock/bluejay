//
//  HeartRateMeasurement.swift
//  DittojayHeartSensorDemo
//
//  Created by Jeremy Chiang on 2019-01-08.
//  Copyright © 2019 Steamclock Software. All rights reserved.
//

import Bluejay
import Foundation

struct HeartRateMeasurement: Sendable {

    private var flags: UInt8 = 0
    private var measurement8bits: UInt8 = 0
    private var measurement16bits: UInt16 = 0
    private var energyExpended: UInt16 = 0
    private var rrInterval: UInt16 = 0

    init(heartRate: UInt8) {
       measurement8bits = heartRate
    }

    func toBluetoothData() -> Data {
        return Bluejay.combine(sendables: [flags, measurement8bits, measurement16bits, energyExpended, rrInterval])
    }

}
