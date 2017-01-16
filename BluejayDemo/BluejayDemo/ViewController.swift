//
//  ViewController.swift
//  BluejayDemo
//
//  Created by Jeremy Chiang on 2017-01-09.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import UIKit
import Bluejay

let heartRateService = ServiceIdentifier(uuid: "180D")
let bodySensorLocation = CharacteristicIdentifier(uuid: "2A38", service: heartRateService)
let heartRate = CharacteristicIdentifier(uuid: "2A37", service: heartRateService)

class ViewController: UIViewController {

    private let bluejay = Bluejay.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    @IBAction func scan() {
        bluejay.scan(service: heartRateService) { (result) in
            switch result {
            case .success(let peripheral):
                print("Scan succeeded with peripheral: \(peripheral.name)")
            case .failure(let error):
                print("Scan failed with error: \(error.localizedDescription)")
            }
        }
    }
    
    @IBAction func read() {
        bluejay.read(from: bodySensorLocation) { (result: BluejayReadResult<IncomingString>) in
            switch result {
            case .success(let value):
                print("Read succeeded with value: \(value.string)")
            case .failure(let error):
                print("Read failed with error: \(error.localizedDescription)")
            }
        }
    }
    
    @IBAction func write() {
        bluejay.write(to: bodySensorLocation, value: OutgoingString("Wrist")) { (result) in
            switch result {
            case .success:
                print("Write succeeded.")
            case .failure(let error):
                print("Write failed with error: \(error.localizedDescription)")
            }
        }
    }
    
    @IBAction func listen() {
        bluejay.listen(to: heartRate) { (result: BluejayReadResult<IncomingInt>) in
            switch result {
            case .success(let value):
                print("Listen succeeded with value: \(value.int)")
            case .failure(let error):
                print("Listen failed with error: \(error.localizedDescription)")
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

struct IncomingString: BluejayReceivable {
    
    var string: String
    
    init(bluetoothData: Data) {
        string = String(data: bluetoothData, encoding: .utf8)!
    }
    
}

struct OutgoingString: BluejaySendable {
    
    var string: String
    
    init(_ string: String) {
        self.string = string
    }
    
    func toBluetoothData() -> Data {
        return string.data(using: .utf8)!
    }
    
}

struct IncomingInt: BluejayReceivable {
    
    var int: Int
    
    init(bluetoothData: Data) {
        var value = 0
        
        (bluetoothData as NSData).getBytes(&value, range: NSRange(location: 0, length: 1))
        
        int = value
    }
    
}
