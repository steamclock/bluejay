//
//  SynchronizedPeripheral.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-05.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import CoreBluetooth
import Foundation

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
         debugLog("Deinit synchronized peripheral: \(parent.identifier.description))")
    }

    // MARK: - Actions

    /// Read a value from the specified characteristic synchronously.
    public func read<R: Receivable>(from characteristicIdentifier: CharacteristicIdentifier) throws -> R {
        var finalResult: ReadResult<R> = .failure(BluejayError.readFailed)

        let sem = DispatchSemaphore(value: 0)

        DispatchQueue.main.async {
            self.parent.read(from: characteristicIdentifier) { (result: ReadResult<R>) in
                finalResult = result
                sem.signal()
            }
            return
        }

        _ = sem.wait(timeout: DispatchTime.distantFuture)

        switch finalResult {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }

    /// Write a value from the specified characteristic synchronously.
    public func write<S: Sendable>(to characteristicIdentifier: CharacteristicIdentifier, value: S, type: CBCharacteristicWriteType = .withResponse) throws {
        var finalResult: WriteResult = .failure(BluejayError.writeFailed)

        let sem = DispatchSemaphore(value: 0)

        DispatchQueue.main.async {
            self.parent.write(to: characteristicIdentifier, value: value, type: type) { result in
                finalResult = result
                sem.signal()
            }
            return
        }

        _ = sem.wait(timeout: DispatchTime.distantFuture)

        if case .failure(let error) = finalResult {
            throw error
        }
    }

    /// Write to one characterestic then reading a value from another.
    public func writeAndRead<R: Receivable, S: Sendable> (
        writeTo: CharacteristicIdentifier,
        value: S,
        type: CBCharacteristicWriteType = .withResponse,
        readFrom: CharacteristicIdentifier) throws -> R {
        try write(to: writeTo, value: value, type: type)
        return try read(from: readFrom)
    }

    /// Listen for changes on a specified characterstic synchronously.
    public func listen<R: Receivable>( // swiftlint:disable:this cyclomatic_complexity
        to characteristicIdentifier: CharacteristicIdentifier,
        timeout: Timeout = .none,
        completion: @escaping (R) -> ListenAction) throws {
        let sem = DispatchSemaphore(value: 0)

        var listenResult: ReadResult<R>?
        var error: Error?

        backupTermination = { bluejayError in
            error = bluejayError
            sem.signal()
        }

        DispatchQueue.main.async {
            self.parent.listen(to: characteristicIdentifier, multipleListenOption: .trap) { (result: ReadResult<R>) in
                listenResult = result
                var action = ListenAction.done

                switch result {
                case .success(let value):
                    action = completion(value)
                case .failure(let failureError):
                    error = failureError
                }

                if error != nil || action == .done {
                    if self.parent.isListening(to: characteristicIdentifier) && self.bluetoothAvailable {
                        self.parent.endListen(to: characteristicIdentifier, error: nil) { result in
                            switch result {
                            case .success:
                                break
                            case .failure(let failureError):
                                // Don't overwrite the more important error from the original listen call.
                                if error == nil {
                                    error = failureError
                                }
                            }

                            sem.signal()
                        }
                    } else {
                        sem.signal()
                    }
                }
            }
        }

        if case let .seconds(timeoutInterval) = timeout {
            _ = sem.wait(timeout: .now() + DispatchTimeInterval.seconds(Int(timeoutInterval)))
        } else {
            _ = sem.wait(timeout: .distantFuture)
        }

        if let error = error {
            backupTermination = nil
            throw error
        } else if listenResult == nil {
            backupTermination = nil

            if self.parent.isListening(to: characteristicIdentifier) && self.bluetoothAvailable {
                self.parent.endListen(to: characteristicIdentifier)
            }

            throw BluejayError.listenTimedOut
        }
    }

    /// Stop listening to a characteristic synchronously.
    public func endListen(to characteristicIdentifier: CharacteristicIdentifier, error: Error? = nil, completion: ((WriteResult) -> Void)? = nil) throws {
        let sem = DispatchSemaphore(value: 0)
        var errorToThrow: Error?

        DispatchQueue.main.async {
            if self.parent.isListening(to: characteristicIdentifier) {
                self.parent.endListen(to: characteristicIdentifier, error: error) { result in
                    switch result {
                    case .success:
                        break
                    case .failure(let endListenError):
                        errorToThrow = endListenError
                    }

                    sem.signal()
                }
            } else {
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

     **Warning** Timeout defaults to 3 seconds. Specifying no timeout or a timeout with zero second will result in a fatal error.

     - Parameters:
        - characteristicIdentifier: The characteristic to flush.
        - nonZeroTimeout: How long to wait for incoming data.
        - completion: Block to call when the flush is complete.
    */
    public func flushListen(to characteristicIdentifier: CharacteristicIdentifier, nonZeroTimeout: Timeout = .seconds(3), completion: @escaping () -> Void) throws {
        guard case let .seconds(timeoutInterval) = nonZeroTimeout, timeoutInterval > 0 else {
            fatalError(BluejayError.indefiniteFlush.errorDescription!)
        }

        let listenSem = DispatchSemaphore(value: 0)
        let endListenSem = DispatchSemaphore(value: 0)
        var error: Error?

        var shouldListenAgain = false

        DispatchQueue.main.async {
            debugLog("Flushing listen to \(characteristicIdentifier.description)")

            shouldListenAgain = false

            self.parent.listen(to: characteristicIdentifier, multipleListenOption: .trap) { (result: ReadResult<Data>) in
                switch result {
                case .success:
                    debugLog("Flushed some data.")

                    shouldListenAgain = true
                case .failure(let failureError):
                    debugLog("Flush failed with error: \(failureError.localizedDescription)")

                    shouldListenAgain = false
                    error = failureError
                }

                listenSem.signal()
            }
        }

        repeat {
            shouldListenAgain = false
            _ = listenSem.wait(timeout: .now() + DispatchTimeInterval.seconds(Int(timeoutInterval)))
            debugLog("Flush to \(characteristicIdentifier.description) finished, should flush again: \(shouldListenAgain).")
        } while shouldListenAgain

        DispatchQueue.main.async {
            if self.parent.isListening(to: characteristicIdentifier) {
                self.parent.endListen(to: characteristicIdentifier, error: nil) { result in
                    switch result {
                    case .success:
                        break
                    case .failure(let failureError):
                        error = failureError
                    }

                    endListenSem.signal()
                }
            } else {
                endListenSem.signal()
            }
        }

        _ = endListenSem.wait(timeout: .now() + DispatchTimeInterval.seconds(Int(timeoutInterval)))

        if let error = error {
            throw error
        }

        completion()
    }

    /**
     Handle a compound operation consisting of writing on one characterstic followed by listening on another for some streamed data.

     Conceptually very similar to just calling write, then listen, except that the listen is set up before the write is issued, so that there should be no risks of data loss due to missed notifications, which there would be with calling them seperatly.
     */
    public func writeAndListen<S: Sendable, R: Receivable>( // swiftlint:disable:this cyclomatic_complexity
        writeTo charToWriteTo: CharacteristicIdentifier,
        value: S,
        type: CBCharacteristicWriteType = .withResponse,
        listenTo charToListenTo: CharacteristicIdentifier,
        timeoutInSeconds: Int = 0,
        completion: @escaping (R) -> ListenAction) throws {
        let sem = DispatchSemaphore(value: 0)

        var listenResult: ReadResult<R>?
        var error: Error?

        backupTermination = { bluejayError in
            error = bluejayError
            sem.signal()
        }

        DispatchQueue.main.sync {
            self.parent.listen(to: charToListenTo, multipleListenOption: .trap) { (result: ReadResult<R>) in
                listenResult = result
                var action: ListenAction = .done

                switch result {
                case .success(let value):
                    action = completion(value)
                case .failure(let failureError):
                    error = failureError
                }

                if error != nil || action == .done {
                    if self.parent.isListening(to: charToListenTo) && self.bluetoothAvailable {
                        self.parent.endListen(to: charToListenTo, error: nil) { result in
                            switch result {
                            case .success:
                                break
                            case .failure(let failureError):
                                // Don't overwrite the more important error from the original listen call.
                                if error == nil {
                                    error = failureError
                                }
                            }

                            sem.signal()
                        }
                    } else {
                        sem.signal()
                    }
                }
            }

            self.parent.write(to: charToWriteTo, value: value, type: type) { result in
                switch result {
                case .success:
                    return
                case .failure(let failureError):
                    error = failureError
                    sem.signal()
                }
            }

        }

        _ = sem.wait(timeout: timeoutInSeconds == 0 ? .distantFuture : .now() + .seconds(timeoutInSeconds))

        if let error = error {
            backupTermination = nil
            throw error
        } else if listenResult == nil {
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
    public func writeAndAssemble<S: Sendable, R: Receivable>( // swiftlint:disable:this cyclomatic_complexity
        writeTo charToWriteTo: CharacteristicIdentifier,
        value: S,
        listenTo charToListenTo: CharacteristicIdentifier,
        expectedLength: Int,
        timeoutInSeconds: Int = 0,
        completion: @escaping (R) -> ListenAction) throws {
        let sem = DispatchSemaphore(value: 0)

        var listenResult: ReadResult<Data>?
        var writeAndAssembleError: Error?

        var assembledData = Data()

        backupTermination = { bluejayError in
            writeAndAssembleError = bluejayError
            sem.signal()
        }

        DispatchQueue.main.sync {
            self.parent.listen(to: charToListenTo, multipleListenOption: .trap) { (result: ReadResult<Data>) in
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
                        } catch {
                            writeAndAssembleError = error
                        }
                    } else {
                        debugLog("Need to continue to assemble data.")
                    }
                case .failure(let error):
                    writeAndAssembleError = error
                }

                if writeAndAssembleError != nil || action == .done {
                    if self.parent.isListening(to: charToListenTo) && self.bluetoothAvailable {
                        self.parent.endListen(to: charToListenTo, error: nil) { result in
                            switch result {
                            case .success:
                                break
                            case .failure(let error):
                                // Don't overwrite the more important error from the original listen call.
                                if writeAndAssembleError == nil {
                                    writeAndAssembleError = error
                                }
                            }

                            sem.signal()
                        }
                    } else {
                        sem.signal()
                    }
                }
            }

            self.parent.write(to: charToWriteTo, value: value) { result in
                switch result {
                case .success:
                    return
                case .failure(let error):
                    writeAndAssembleError = error
                    sem.signal()
                }
            }
        }

        _ = sem.wait(timeout: timeoutInSeconds == 0 ? .distantFuture : .now() + .seconds(timeoutInSeconds))

        if let error = writeAndAssembleError {
            backupTermination = nil
            throw error
        } else if listenResult == nil {
            backupTermination = nil

            if self.parent.isListening(to: charToListenTo) && self.bluetoothAvailable {
                self.parent.endListen(to: charToListenTo)
            }

            throw BluejayError.listenTimedOut
        }
    }

    /// Ask for the peripheral's maximum payload length in bytes for a single write request.
    public func maximumWriteValueLength(`for` writeType: CBCharacteristicWriteType) -> Int {
        return parent.maximumWriteValueLength(for: writeType)
    }

}

extension SynchronizedPeripheral: ConnectionObserver {

    public func bluetoothAvailable(_ available: Bool) {
        bluetoothAvailable = available

        if !available {
            backupTermination?(BluejayError.bluetoothUnavailable)
        }
    }

    public func disconnected(from peripheral: PeripheralIdentifier) {
        backupTermination?(BluejayError.notConnected)
    }

}
