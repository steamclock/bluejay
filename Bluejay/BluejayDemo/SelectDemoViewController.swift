//
//  SelectDemoViewController.swift
//  Bluejay
//
//  Created by Jeremy Chiang on 2017-04-28.
//  Copyright © 2017 Steamclock Software. All rights reserved.
//

import UIKit

class SelectDemoViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        clearsSelectionOnViewWillAppear = true
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 3
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Choose a demo"
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "demoCell", for: indexPath)

        switch indexPath.row {
        case 0:
            cell.textLabel?.text = "Scan Everything"
        case 1:
            cell.textLabel?.text = "Heart Rate Sensor"
        case 2:
            cell.textLabel?.text = "Connect using Serial Number"
        default:
            cell.textLabel?.text = ""
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.row {
        case 0:
            performSegue(withIdentifier: "showScanEverything", sender: self)
        case 1:
            performSegue(withIdentifier: "showScanHeartSensors", sender: self)
        case 2:
            performSegue(withIdentifier: "showConnectUsingSerial", sender: self)
        default:
            break
        }
    }

}
