//
//  LogViewController.swift
//  BluejayHeartSensorDemo
//
//  Created by Jeremy Chiang on 2019-01-02.
//  Copyright © 2019 Steamclock Software. All rights reserved.
//

import Bluejay
import UIKit

// should only ever be one of these, keep a local reference to it so we can implement a general
// debug logging free function below
private weak var logViewControllerInstance: LogViewController?

func debugLog(_ text: String) {
    logViewControllerInstance?.logTextView.text.append(text + "\n")
}

class LogViewController: UIViewController {

    @IBOutlet fileprivate var logTextView: UITextView!

    override func viewDidLoad() {
        super.viewDidLoad()
        clearLogs()
        bluejay.register(logObserver: self)
    }

    @IBAction func clearLogs() {
        logTextView.text = ""
    }

    @IBAction func exportLogs() {
        present(UIActivityViewController(activityItems: [logTextView.text ?? ""], applicationActivities: nil), animated: true, completion: nil)
    }

}

extension LogViewController: LogObserver {
    func debug(_ text: String) {
        logTextView.text.append(text + "\n")
    }

}
