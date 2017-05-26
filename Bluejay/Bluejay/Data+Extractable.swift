//
//  Data+Extractable.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-05-26.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation

extension Data {
    
    public func extract<T>(start: Int, length: Int) -> T {
        return self.subdata(in: start..<start+length).withUnsafeBytes { $0.pointee }
    }
    
}
