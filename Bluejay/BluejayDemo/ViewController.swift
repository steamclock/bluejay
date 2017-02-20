//
//  ViewController.swift
//  BluejayDemo
//
//  Created by Jeremy Chiang on 2017-01-09.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import UIKit
import Bluejay
import CoreBluetooth

let heartRateService = ServiceIdentifier(uuid: "180D")
let bodySensorLocation = CharacteristicIdentifier(uuid: "2A38", service: heartRateService)
let heartRate = CharacteristicIdentifier(uuid: "2A37", service: heartRateService)

class ViewController: UIViewController {
    
    fileprivate let bluejay = Bluejay.shared
    
    @IBOutlet var statusLabel: UILabel!
    @IBOutlet var deviceLabel: UILabel!
    @IBOutlet var bpmLabel: UILabel!
    @IBOutlet var logTextView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.updateLog(notification:)), name: .logDidUpdate, object: nil)
        
        bluejay.start(connectionObserver: self, listenRestorer: self, enableBackgroundMode: true)
    }
    
    func updateLog(notification: Notification) {
        DispatchQueue.main.async {
            if let logContent = notification.userInfo?[bluejayLogContent] as? String {
                self.logTextView.text = logContent
                
                // Scroll to the bottom.
                self.logTextView.scrollRectToVisible(self.logTextView.caretRect(for: self.logTextView.endOfDocument), animated: true)
            }
        }
    }
    
    @IBAction func scan() {
        bluejay.scan(serviceIdentifier: heartRateService) { (result) in
            switch result {
            case .success(let scannedPeripherals):
                log.debug("Scan succeeded with peripherals: \(scannedPeripherals)")
                
                self.bluejay.connect(PeripheralIdentifier(uuid: "\(scannedPeripherals.first!.0.identifier)")!, completion: { (result) in
                    switch result {
                    case .success(let peripheral):
                        log.debug("Connect succeeded with peripheral: \(peripheral)")
                    case .failure(let error):
                        log.debug("Connect failed with error: \(error.localizedDescription)")
                    }
                })
            case .failure(let error):
                log.debug("Scan failed with error: \(error.localizedDescription)")
            }
        }
    }
    
    @IBAction func read() {
        bluejay.read(from: bodySensorLocation) { (result: ReadResult<String>) in
            switch result {
            case .success(let value):
                log.debug("Read succeeded with value: \(value)")
            case .failure(let error):
                log.debug("Read failed with error: \(error.localizedDescription)")
            }
        }
    }
    
    @IBAction func write() {
        bluejay.write(to: bodySensorLocation, value: "Wrist") { (result) in
            switch result {
            case .success:
                log.debug("Write succeeded.")
            case .failure(let error):
                log.debug("Write failed with error: \(error.localizedDescription)")
            }
        }
    }
    
    @IBAction func disconect() {
        bluejay.disconnect()
    }
    
    @IBAction func listen() {
        bluejay.listen(to: heartRate) { (result: ReadResult<UInt8>) in
            switch result {
            case .success(let value):
                log.debug("Listen succeeded with value: \(value)")
            case .failure(let error):
                log.debug("Listen failed with error: \(error.localizedDescription)")
            }
        }
    }
    
    @IBAction func endListen() {
        bluejay.endListen(to: heartRate)
    }
    
    @IBAction func crash() {
        kill(getpid(), SIGKILL)
    }
    
    @IBAction func clearLog() {
        bluejay.clearLog()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}

extension ViewController: ConnectionObserver {
    
    func bluetoothAvailable(_ available: Bool) {
        DispatchQueue.main.async {
            self.statusLabel.text = available ? "Available" : "Not Available"
        }
    }
    
    func connected(_ peripheral: Peripheral) {
        DispatchQueue.main.async {
            self.deviceLabel.text = peripheral.name ?? "Connected"
        }
    }
    
    func disconected() {
        DispatchQueue.main.async {
            self.deviceLabel.text = "Disconnected"
        }
    }
    
}

extension ViewController: ListenRestorer {
    
    func willRestoreListen(on characteristic: CharacteristicIdentifier) -> Bool {
        if characteristic == heartRate {
            bluejay.restoreListen(to: heartRate, completion: { (result: ReadResult<UInt8>) in
                switch result {
                case .success(let value):
                    log.debug("Listen succeeded with value: \(value)")
                case .failure(let error):
                    log.debug("Listen failed with error: \(error.localizedDescription)")
                }
            })
            
            return true
        }
        
        return false
    }
    
}
