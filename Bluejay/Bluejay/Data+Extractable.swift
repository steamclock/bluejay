//
//  Data+Extractable.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-05-26.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation

extension Data {

    /**
     Convenience function to read a range of Data and deserialize it into the specified type.
     
     - Parameters:
        - start: The starting position of the range to read.
        - length: The number of bytes to read from `start`.
    */
    public func extract<T>(start: Int, length: Int) throws -> T {
        if start + length > self.count {
            throw BluejayError.dataOutOfBounds(start: start, length: length, count: self.count)
        }

        return self.subdata(in: start..<start + length).withUnsafeBytes { $0.load(as: T.self) }
    }

}
