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
    A synchronous interface to the Bluetooth peripheral, intended to be used inside the backgroundTask block of `run(backgroundTask:completionOnMainThread:)` to perform multi-part operations without the need for a complicated callback or promise setup.
*/
public class SynchronizedPeripheral {
    
    // MARK: - Properties
    
    private var parent: Peripheral
    
    private var bluetoothAvailable = false
    private var backupTermination: ((BluejayError) -> Void)?
    
    // MARK: - Initialization
    
    init(parent: Peripheral) {
        self.parent = parent
    }
    
    deinit {
        log("Deinit synchronized peripheral: \(String(describing: parent.cbPeripheral.name ?? parent.cbPeripheral.identifier.uuidString))")
    }
    
    // MARK: - Actions
    
    /// Read a value from the specified characteristic synchronously.
    public func read<R: Receivable>(from characteristicIdentifier: CharacteristicIdentifier) throws -> R {
        var finalResult: ReadResult<R> = .failure(BluejayError.readFailed)
        
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
            throw BluejayError.cancelled
        case .failure(let error):
            throw error
        }
    }
    
    /// Write a value from the specified characteristic synchronously.
    public func write<S: Sendable>(to characteristicIdentifier: CharacteristicIdentifier, value: S, type: CBCharacteristicWriteType = .withResponse) throws {
        var finalResult: WriteResult = .failure(BluejayError.writeFailed)
        
        let sem = DispatchSemaphore(value: 0)
        
        DispatchQueue.main.async {
            self.parent.write(to: characteristicIdentifier, value: value, type: type, completion: { (result) in
                finalResult = result
                sem.signal()
            })
            return
        }
        
        _ = sem.wait(timeout: DispatchTime.distantFuture)
        
        if case .cancelled = finalResult {
            throw BluejayError.cancelled
        }
        else if case .failure(let error) = finalResult {
            throw error
        }
    }
    
    /// Write to one characterestic then reading a value from another.
    public func writeAndRead<R: Receivable, S: Sendable> (writeTo: CharacteristicIdentifier, value: S, type: CBCharacteristicWriteType = .withResponse, readFrom: CharacteristicIdentifier) throws -> R {
        try write(to: writeTo, value: value, type: type)
        return try read(from: readFrom)
    }
    
    /// Listen for changes on a specified characterstic synchronously.
    public func listen<R: Receivable>(to characteristicIdentifier: CharacteristicIdentifier, completion: @escaping (R) -> ListenAction) throws {
        let sem = DispatchSemaphore(value: 0)
        var error : Error?
        
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
                    if self.parent.isListening(to: characteristicIdentifier) && self.bluetoothAvailable {
                        self.parent.endListen(to: characteristicIdentifier, error: nil, completion: { (result) in
                            switch result {
                            case .success:
                                break
                            case .cancelled:
                                // Don't overwrite the more important error from the original listen call.
                                if error == nil {
                                    error = BluejayError.endListenCancelled
                                }
                            case .failure(let e):
                                // Don't overwrite the more important error from the original listen call.
                                if error == nil {
                                    error = e
                                }
                            }
                            
                            sem.signal()
                        })
                    } else {
                        sem.signal()
                    }
                }
            })
        }
        
        _ = sem.wait(timeout: DispatchTime.distantFuture)
        
        if let error = error {
            throw error
        }
    }
    
    /// Stop listening to a characteristic synchronously.
    public func endListen(to characteristicIdentifier: CharacteristicIdentifier, error: Error? = nil, completion: ((WriteResult) -> Void)? = nil) throws {
        let sem = DispatchSemaphore(value: 0)
        var errorToThrow: Error?
        
        DispatchQueue.main.async {
            if self.parent.isListening(to: characteristicIdentifier) {
                self.parent.endListen(to: characteristicIdentifier, error: error, completion: { (result) in
                    switch result {
                    case .success:
                        break
                    case .cancelled:
                        errorToThrow = BluejayError.endListenCancelled
                    case .failure(let endListenError):
                        errorToThrow = endListenError
                    }
                    
                    sem.signal()
                })
            }
            else {
                sem.signal()
            }
        }
        
        _ = sem.wait(timeout: .distantFuture)

        if let errorToThrow = errorToThrow {
            throw errorToThrow
        }
    }
    
    /**
     Flush a listen to a characteristic by receiving and discarding values for the specified duration.
     
     - Parameters:
        - characteristicIdentifier: The characteristic to flush.
        - idleWindow: How long to flush for in seconds.
        - completion: Block to call when the flush is complete.
    */
    public func flushListen(to characteristicIdentifier: CharacteristicIdentifier, idleWindow: Int = 3, completion: @escaping () -> Void) throws {
        let flushSem = DispatchSemaphore(value: 0)
        let cleanUpSem = DispatchSemaphore(value: 0)
        let sem = DispatchSemaphore(value: 0)
        var error : Error?
        
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
            
            _ = flushSem.wait(timeout: .now() + .seconds(idleWindow))
            
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
            
            _ = cleanUpSem.wait(timeout: .distantFuture)
            
            DispatchQueue.main.async {
                log("Flush to \(characteristicIdentifier.uuid.uuidString) finished, should flush again: \(shouldListenAgain).")

                if !shouldListenAgain {
                    sem.signal()
                }
            }
        } while shouldListenAgain
        
        _ = sem.wait(timeout: .distantFuture)
        
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
        type: CBCharacteristicWriteType = .withResponse,
        listenTo charToListenTo: CharacteristicIdentifier,
        timeoutInSeconds: Int = 0,
        completion: @escaping (R) -> ListenAction) throws
    {
        let sem = DispatchSemaphore(value: 0)
        
        var listenResult: ReadResult<R>?
        var error: Error?
        
        backupTermination = { bluejayError in
            error = bluejayError
            sem.signal()
        }
        
        DispatchQueue.main.sync {
            self.parent.listen(to: charToListenTo, completion: { (result : ReadResult<R>) in
                listenResult = result
                var action: ListenAction = .done
                
                switch result {
                case .success(let r):
                    action = completion(r)
                case .cancelled:
                    error = BluejayError.cancelled
                case .failure(let e):
                    error = e
                }
                
                if error != nil || action == .done {
                    if self.parent.isListening(to: charToListenTo) && self.bluetoothAvailable {
                        self.parent.endListen(to: charToListenTo, error: nil, completion: { (result) in
                            switch result {
                            case .success:
                                break
                            case .cancelled:
                                // Don't overwrite the more important error from the original listen call.
                                if error == nil {
                                    error = BluejayError.endListenCancelled
                                }
                            case .failure(let e):
                                // Don't overwrite the more important error from the original listen call.
                                if error == nil {
                                    error = e
                                }
                            }
                            
                            sem.signal()
                        })
                    } else {
                        sem.signal()
                    }
                }
            })
            
            self.parent.write(to: charToWriteTo, value: value, type: type, completion: { result in
                switch result {
                case .success:
                    return
                case .cancelled:
                    error = BluejayError.cancelled
                    sem.signal()
                case .failure(let e):
                    error = e
                    sem.signal()
                }
            })
            
        }
        
        _ = sem.wait(timeout: timeoutInSeconds == 0 ? .distantFuture : .now() + .seconds(timeoutInSeconds))
        
        if let error = error {
            backupTermination = nil
            throw error
        }
        else if listenResult == nil {
            backupTermination = nil
            
            if self.parent.isListening(to: charToListenTo) && self.bluetoothAvailable {
                self.parent.endListen(to: charToListenTo)
            }
            
            throw BluejayError.listenTimedOut
        }
    }
    
    /**
     Similar to `writeAndListen`, but use this if you don't know or don't have control over how many packets will be sent to you. You still need to know the total size of the data you're receiving.
     */
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
        var writeAndAssembleError: Error?
        
        var assembledData = Data()
        
        backupTermination = { bluejayError in
            writeAndAssembleError = bluejayError
            sem.signal()
        }
        
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
                        do {
                            action = completion(try R(bluetoothData: assembledData))
                        }
                        catch {
                            writeAndAssembleError = error
                        }
                    }
                    else {
                        log("Need to continue to assemble data.")
                    }
                case .cancelled:
                    writeAndAssembleError = BluejayError.cancelled
                case .failure(let e):
                    writeAndAssembleError = e
                }
                
                if writeAndAssembleError != nil || action == .done {
                    if self.parent.isListening(to: charToListenTo) && self.bluetoothAvailable {
                        self.parent.endListen(to: charToListenTo, error: nil, completion: { (result) in
                            switch result {
                            case .success:
                                break
                            case .cancelled:
                                // Don't overwrite the more important error from the original listen call.
                                if writeAndAssembleError == nil {
                                    writeAndAssembleError = BluejayError.endListenCancelled
                                }
                            case .failure(let e):
                                // Don't overwrite the more important error from the original listen call.
                                if writeAndAssembleError == nil {
                                    writeAndAssembleError = e
                                }
                            }
                            
                            sem.signal()
                        })
                    } else {
                        sem.signal()
                    }
                }
            })
            
            self.parent.write(to: charToWriteTo, value: value, completion: { result in
                switch result {
                case .success:
                    return
                case .cancelled:
                    writeAndAssembleError = BluejayError.cancelled
                    sem.signal()
                case .failure(let e):
                    writeAndAssembleError = e
                    sem.signal()
                }
            })
        }
        
        _ = sem.wait(timeout: timeoutInSeconds == 0 ? .distantFuture : .now() + .seconds(timeoutInSeconds))
        
        if let error = writeAndAssembleError {
            backupTermination = nil
            throw error
        }
        else if listenResult == nil {
            backupTermination = nil
            
            if self.parent.isListening(to: charToListenTo) && self.bluetoothAvailable {
                self.parent.endListen(to: charToListenTo)
            }
            
            throw BluejayError.listenTimedOut
        }
    }
    
}

extension SynchronizedPeripheral: ConnectionObserver {
    
    public func bluetoothAvailable(_ available: Bool) {
        bluetoothAvailable = available
        
        if !available {
            backupTermination?(BluejayError.bluetoothUnavailable)
        }
    }
    
    public func disconnected(from peripheral: Peripheral) {
        backupTermination?(BluejayError.notConnected)
    }
    
}
