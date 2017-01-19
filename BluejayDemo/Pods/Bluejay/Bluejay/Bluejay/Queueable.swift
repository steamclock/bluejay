//
//  Queueable.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-19.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation

protocol Queueable {
    
    var state: OperationState { get }
    
    func start()
    func process(event: Event)
    func fail(_ error: NSError)
    
}
