//
//  Logger.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-01-16.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import Foundation
import XCGLogger

public let log = XCGLogger(identifier: "bluejayLogger", includeDefaultDestinations: false)

private let systemDestinationIdentifier = "bluejayLogger.systemDestination"
private let fileDestinationIdentifier = "bluejayLogger.fileDestination"
private let systemDestination = AppleSystemLogDestination(identifier: systemDestinationIdentifier)
private let bluejayLogFileName = "bluejay-log"

public let bluejayLogContent = "bluejayLogContent"

class Logger {
    
    static let shared = Logger()
    
    private var logFileMonitorSource: DispatchSource?
    private var logFileDescriptor: CInt = 0
    
    init() {
        setupLogger()
    }
    
    // MARK: - Setup Logger
    
    private func setupLogger() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(Logger.checkLogFileSize),
            name: Notification.Name.UIApplicationDidBecomeActive,
            object: nil
        )
        
        systemDestination.outputLevel = .debug
        systemDestination.showLogIdentifier = true
        systemDestination.showFunctionName = true
        systemDestination.showThreadName = true
        systemDestination.showLevel = true
        systemDestination.showFileName = true
        systemDestination.showLineNumber = true
        systemDestination.showDate = true
        
        log.add(destination: systemDestination)
        
//        let documentURLs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
//        
//        guard let documentURL = documentURLs.first else {
//            return
//        }
//        
//        let logFileURL = documentURL.appendingPathComponent(bluejayLogFileName)
//        addFileDestination(logFileURL)
//        
//        beginMonitoringLogFile()
    }
    
    private func addFileDestination(_ logFileURL: URL) {
        let fileDestination = FileDestination(
            owner: log,
            writeToFile: logFileURL,
            identifier: fileDestinationIdentifier,
            shouldAppend: true
        )
        
        // Optionally set some configuration options
        fileDestination.outputLevel = .debug
        fileDestination.showLogIdentifier = false
        fileDestination.showFunctionName = true
        fileDestination.showThreadName = true
        fileDestination.showLevel = true
        fileDestination.showFileName = true
        fileDestination.showLineNumber = true
        fileDestination.showDate = true
        
        // Process this destination in the background
        fileDestination.logQueue = XCGLogger.logQueue
        
        // Add the destination to the logger
        log.add(destination: fileDestination)
        
        // Add basic app info, version info etc, to the start of the logs
        log.logAppDetails()
        
        beginMonitoringLogFile()
    }
    
    @objc private func checkLogFileSize() {
//        let documentURLs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
//        
//        if let documentURL = documentURLs.first {
//            let logFileURL = documentURL.appendingPathComponent(bluejayLogFileName)
//            
//            do {
//                let fileAttributes : NSDictionary? = try FileManager.default.attributesOfItem(atPath: logFileURL.path) as NSDictionary?
//                
//                if let logFileAttributes = fileAttributes {
//                    log.debug("Log file size: \(logFileAttributes.fileSize())")
//                    
//                    if logFileAttributes.fileSize() > 102400 {
//                        log.debug("Log rolling over due file size exceeding 100KB.")
//                        
//                        // Remove log file destination before recreating the log file.
//                        log.remove(destinationWithIdentifier: fileDestinationIdentifier)
//                        
//                        // Create a new blank log file.
//                        FileManager.default.createFile(atPath: logFileURL.path, contents: nil, attributes: nil)
//                        
//                        // Re-add log file destination.
//                        addFileDestination(logFileURL)
//                    }
//                }
//            }
//            catch {
//                log.debug("Unable to read log file attributes.")
//            }
//        }
    }
    
    private func fetchLogs() {
        let documentURLs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        
        if let documentURL = documentURLs.first {
            let logFileURL = documentURL.appendingPathComponent(bluejayLogFileName)
            
            do {
                let logContent = try String(contentsOf: logFileURL)
                NotificationCenter.default.post(name: .logDidUpdate, object: self, userInfo: [bluejayLogContent : logContent])
            }
            catch {
                print("Failed to read from the logs file with error: \(error)")
            }
        }
    }
    
    private func beginMonitoringLogFile() {
        let documentURLs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        
        guard let documentURL = documentURLs.first else { return }
        
        let logFileURL = documentURL.appendingPathComponent(bluejayLogFileName)
        
        logFileDescriptor = open(FileManager.default.fileSystemRepresentation(withPath: logFileURL.path), O_EVTONLY)
        
        let logFileMonitorQueue = DispatchQueue.global()
        
        logFileMonitorSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: logFileDescriptor,
            eventMask: DispatchSource.FileSystemEvent.write,
            queue: logFileMonitorQueue
            ) /*Migrator FIXME: Use DispatchSourceFileSystemObject to avoid the cast*/ as? DispatchSource
        
        guard let logFileMonitorSource = logFileMonitorSource else { return }
        
        logFileMonitorSource.setEventHandler {
            DispatchQueue.main.async {
                self.fetchLogs()
            }
        }
        
        logFileMonitorSource.setCancelHandler {
            close(self.logFileDescriptor)
            self.logFileDescriptor = 0
            self.logFileMonitorSource = nil
        }
        
        logFileMonitorSource.resume()
    }
    
    func clearLog() {
        let documentURLs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        
        if let documentURL = documentURLs.first {
            let logFileURL = documentURL.appendingPathComponent(bluejayLogFileName)
            
            try? Data().write(to: URL(fileURLWithPath: logFileURL.path), options: [])
            fetchLogs()
        }
    }
    
}
