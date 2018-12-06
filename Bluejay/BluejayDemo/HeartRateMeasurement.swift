//
//  HeartRateMeasurement.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-06-23.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Bluejay
import Foundation

// https://www.bluetooth.com/specifications/gatt/viewer?attributeXmlFile=org.bluetooth.characteristic.heart_rate_measurement.xml

struct HeartRateMeasurement: Receivable {

    private var flags: UInt8 = 0
    private var measurement8bits: UInt8 = 0
    private var measurement16bits: UInt16 = 0
    private var energyExpended: UInt16 = 0
    private var rrInterval: UInt16 = 0

    private var isMeasurementIn8bits = true

    var measurement: Int {
        return isMeasurementIn8bits ? Int(measurement8bits) : Int(measurement16bits)
    }

    init(bluetoothData: Data) throws {
        flags = try bluetoothData.extract(start: 0, length: 1)

        isMeasurementIn8bits = (flags & 0b00000001) == 0b00000000

        if isMeasurementIn8bits {
            measurement8bits = try bluetoothData.extract(start: 1, length: 1)
        } else {
            measurement16bits = try bluetoothData.extract(start: 1, length: 2)
        }
    }

}
