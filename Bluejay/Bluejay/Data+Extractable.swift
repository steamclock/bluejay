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
     Convenience function to read a range of Data and deserialize it into a fixed width type.
     
     - Parameters:
        - start: The starting position of the range to read.
        - length: The number of bytes to read from `start`.
    */
    public func extract<T: FixedWidth>(start: Int, length: Int) throws -> T {
        if start + length > self.count {
            throw BluejayError.dataOutOfBounds(start: start, length: length, count: self.count)
        }

        return self.subdata(in: start..<start + length).withUnsafeBytes { $0.pointee }
    }

    /**
     Convenience function to extract a range of Data.

     - Parameters:
        - start: The starting position of the range to read.
        - length: The number of bytes to read from `start`.
     */
    public func extract(start: Int, length: Int) throws -> Data {
        return self.subdata(in: start..<start + length)
    }

    /**
     Convenience function to read a range of Data and deserialize it into a String.

     - Note: Defaults to using utf8 encoding.

     - Parameters:
        - start: The starting position of the range to read.
        - length: The number of bytes to read from `start`.
        - encoding: The string encoding to use, defaults to utf8.
     */
    public func extract(start: Int, length: Int, encoding: String.Encoding = .utf8) throws -> String? {
        return String(data: self.subdata(in: start..<start + length), encoding: encoding)
    }
}
