//
//  LogViewController.swift
//  BluejayHeartSensorDemo
//
//  Created by Jeremy Chiang on 2019-01-02.
//  Copyright © 2019 Steamclock Software. All rights reserved.
//

import Bluejay
import UIKit

class LogViewController: UIViewController {

    @IBOutlet private var logTextView: UITextView!

    override func viewDidLoad() {
        super.viewDidLoad()

        logTextView.text = bluejay.getLogs()

        bluejay.register(logObserver: self)
    }

    @IBAction func exportLogs() {
        present(UIActivityViewController(activityItems: [bluejay.getLogs() ?? ""], applicationActivities: nil), animated: true, completion: nil)
    }

}

extension LogViewController: LogObserver {

    func logFileUpdated(logs: String) {
        logTextView.text = logs
        logTextView.scrollRectToVisible(logTextView.caretRect(for: logTextView.endOfDocument), animated: true)
    }

}
