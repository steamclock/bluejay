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
    public func extract<T>(start: Int, length: Int) -> T {
        return self.subdata(in: start..<start+length).withUnsafeBytes { $0.pointee }
    }
    
}
