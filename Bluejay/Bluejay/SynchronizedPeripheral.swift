//
//  SynchronizedPeripheral.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-05.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import CoreBluetooth

/**
    A synchronous interface to the Bluetooth peripheral, intended to be used from a background thread to perform multi-part operations without the need for a complicated callback or promise setup.
*/
public class SynchronizedPeripheral {
    
    // MARK: - Properties
    
    private var parent: Peripheral
    
    // MARK: - Initialization
    
    init(parent: Peripheral) {
        self.parent = parent
    }
    
    // MARK: - Actions
    
    /// Read a value from the specified characteristic synchronously.
    public func read<R: Receivable>(from characteristicIdentifier: CharacteristicIdentifier) throws -> R {
        var finalResult: ReadResult<R> = .failure(Error.readFailed())
        
        let sem = DispatchSemaphore(value: 0)
        
        DispatchQueue.main.async {
            self.parent.read(from: characteristicIdentifier, completion: { (result : ReadResult<R>) in
                finalResult = result
                sem.signal()
            })
            return
        }
        
        _ = sem.wait(timeout: DispatchTime.distantFuture)
        
        switch finalResult {
        case .success(let r):
            return r
        case .cancelled:
            throw Error.cancelled()
        case .failure(let error):
            throw error
        }
    }
    
    /// Write a value from the specified characteristic synchronously.
    public func write<S: Sendable>(to characteristicIdentifier: CharacteristicIdentifier, value: S) throws {
        var finalResult: WriteResult = .failure(Error.writeFailed())
        
        let sem = DispatchSemaphore(value: 0)
        
        DispatchQueue.main.async {
            self.parent.write(to: characteristicIdentifier, value: value, completion: { (result) in
                finalResult = result
                sem.signal()
            })
            return
        }
        
        _ = sem.wait(timeout: DispatchTime.distantFuture)
        
        if case .cancelled = finalResult {
            throw Error.cancelled()
        }
        else if case .failure(let error) = finalResult {
            throw error
        }
    }
    
    /// Listen for changes on a specified characterstic synchronously.
    public func listen<R: Receivable>(to characteristicIdentifier: CharacteristicIdentifier, completion: @escaping (R) -> ListenAction) throws {
        let sem = DispatchSemaphore(value: 0)
        var error : Swift.Error?
        
        DispatchQueue.main.async {
            self.parent.listen(to: characteristicIdentifier, completion: { (result : ReadResult<R>) in
                var action = ListenAction.done
                
                switch result {
                case .success(let r):
                    action = completion(r)
                case .cancelled:
                    sem.signal()
                case .failure(let e):
                    error = e
                }
                                
                if error != nil || action == .done {
                    if self.parent.isListening(to: characteristicIdentifier) {
                        // TODO: Handle end listen failures.
                        self.parent.endListen(to: characteristicIdentifier)
                    }
                }
            })
        }
        
        _ = sem.wait(timeout: DispatchTime.distantFuture)
        
        if let error = error {
            throw error
        }
    }
    
    public func flushListen(to characteristicIdentifier: CharacteristicIdentifier, idleWindow: Int = 3, completion: @escaping () -> Void) throws {
        let flushSem = DispatchSemaphore(value: 0)
        let cleanUpSem = DispatchSemaphore(value: 0)
        let sem = DispatchSemaphore(value: 0)
        var error : Swift.Error?
        
        var shouldListenAgain = false
        
        repeat {
            DispatchQueue.main.async {
                log("Flushing listen to \(characteristicIdentifier.uuid.uuidString)")
                
                shouldListenAgain = false
                
                self.parent.listen(to: characteristicIdentifier, completion: { (result : ReadResult<Data>) in
                    switch result {
                    case .success:
                        log("Flushed some data.")
                        shouldListenAgain = true
                        
                        flushSem.signal()
                    case .cancelled:
                        break
                    case .failure(let e):
                        log("Flush failed with error: \(e.localizedDescription)")
                        shouldListenAgain = false
                        error = e
                        
                        flushSem.signal()
                    }
                })
            }
            
            _ = flushSem.wait(timeout: DispatchTime.now() + .seconds(idleWindow))
            
            DispatchQueue.main.async {
                if self.parent.isListening(to: characteristicIdentifier) {
                    self.parent.endListen(to: characteristicIdentifier, error: nil, completion: { (result) in
                        switch result {
                        case .success:
                            break
                        case .cancelled:
                            break
                        case .failure(let e):
                            error = e
                        }
                        
                        cleanUpSem.signal()
                    })
                }
            }
            
            _ = cleanUpSem.wait(timeout: DispatchTime.distantFuture)
            
            DispatchQueue.main.async {
                log("Flush to \(characteristicIdentifier.uuid.uuidString) finished, should flush again: \(shouldListenAgain).")

                if !shouldListenAgain {
                    sem.signal()
                }
            }
        } while shouldListenAgain
        
        _ = sem.wait(timeout: DispatchTime.distantFuture)
        
        if let error = error {
            throw error
        }
        
        completion()
    }
    
    /**
        Handle a compound operation consisting of writing on one characterstic followed by listening on another for some streamed data.
     
        Conceptually very similar to just calling write, then listen, except that the listen is set up before the write is issued, so that there should be no risks of data loss due to missed notifications, which there would be with calling them seperatly.
    */
    public func writeAndListen<S: Sendable, R:Receivable>(
        writeTo charToWriteTo: CharacteristicIdentifier,
        value: S,
        listenTo charToListenTo: CharacteristicIdentifier,
        timeoutInSeconds: Int = 0,
        completion: @escaping (R) -> ListenAction) throws
    {
        let sem = DispatchSemaphore(value: 0)
        
        var listenResult: ReadResult<R>?
        var error: Swift.Error?
        
        DispatchQueue.main.sync {
            self.parent.listen(to: charToListenTo, completion: { (result : ReadResult<R>) in
                listenResult = result
                var action = ListenAction.done
                
                switch result {
                case .success(let r):
                    action = completion(r)
                case .cancelled:
                    sem.signal()
                case .failure(let e):
                    error = e
                }
                
                if error != nil || action == .done {
                    if self.parent.isListening(to: charToListenTo) {
                        // TODO: Handle end listen failures.
                        self.parent.endListen(to: charToListenTo)
                    }
                }
            })
            
            self.parent.write(to: charToWriteTo, value: value, completion: { result in
                if case .failure(let e) = result {
                    error = e
                    
                    if self.parent.isListening(to: charToListenTo) {
                        // TODO: Handle end listen failures.
                        self.parent.endListen(to: charToListenTo)
                    }
                }
            })
            
        }
        
        _ = sem.wait(timeout: timeoutInSeconds == 0 ? DispatchTime.distantFuture : DispatchTime.now() + .seconds(timeoutInSeconds))
        
        if let error = error {
            throw error
        }
        else if listenResult == nil {
            if self.parent.isListening(to: charToListenTo) {
                // TODO: Handle end listen failures.
                self.parent.endListen(to: charToListenTo)
            }
            
            throw Error.listenTimedOut()
        }
    }
    
    public func writeAndAssemble<S: Sendable, R: Receivable>(
        writeTo charToWriteTo: CharacteristicIdentifier,
        value: S,
        listenTo charToListenTo: CharacteristicIdentifier,
        expectedLength: Int,
        timeoutInSeconds: Int = 0,
        completion: @escaping (R) -> ListenAction) throws
    {
        let sem = DispatchSemaphore(value: 0)
        
        var listenResult: ReadResult<Data>?
        var error: Swift.Error?
        
        var assembledData = Data()
        
        DispatchQueue.main.sync {
            self.parent.listen(to: charToListenTo, completion: { (result : ReadResult<Data>) in
                listenResult = result
                
                var action = ListenAction.keepListening
                
                switch result {
                case .success(let data):
                    if assembledData.count < expectedLength {
                        assembledData.append(data)
                    }
                    
                    if assembledData.count == expectedLength {
                        action = completion(R(bluetoothData: assembledData))
                    }
                    else {
                        log("Need to continue to assemble data.")
                    }
                case .cancelled:
                    action = .done
                    sem.signal()
                case .failure(let e):
                    action = .done
                    error = e
                }
                
                if error != nil || action == .done {
                    if self.parent.isListening(to: charToListenTo) {
                        // TODO: Handle end listen failures.
                        self.parent.endListen(to: charToListenTo)
                    }
                }
            })
            
            self.parent.write(to: charToWriteTo, value: value, completion: { result in
                if case .failure(let e) = result {
                    error = e
                    
                    if self.parent.isListening(to: charToListenTo) {
                        // TODO: Handle end listen failures.
                        self.parent.endListen(to: charToListenTo)
                    }
                }
            })
            
        }
        
        _ = sem.wait(timeout: timeoutInSeconds == 0 ? DispatchTime.distantFuture : DispatchTime.now() + .seconds(timeoutInSeconds))
        
        if self.parent.isListening(to: charToListenTo) {
            // TODO: Handle end listen failures.
            self.parent.endListen(to: charToListenTo)
        }
        
        if let error = error {
            throw error
        }
        else if listenResult == nil {
            throw Error.listenTimedOut()
        }
    }
    
}
