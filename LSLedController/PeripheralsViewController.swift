//
//  PeripheralsViewController.swift
//  LSLedController
//
//  Created by Luca Soldi on 12/09/18.
//  Copyright © 2018 Luca Soldi. All rights reserved.
//

import UIKit
import CoreBluetooth

class PeripheralsViewController: UIViewController, BLESerialManagerDelegate, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var tableView: UITableView!
    
    private var progressHUD : MBProgressHUD!
    
    private var peripheralsArray : [(peripheral: CBPeripheral, RSSI: Float)] = [] {
        didSet {
            self.tableView.reloadData()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        BLESerialManager.shared.delegate = self
        BLESerialManager.shared.startScanPeripheralWithService(CBUUID(string:"FFE0"), characteristic: CBUUID(string:"FFE1"))
    }
    
    @IBAction func reloadButtonPressed(_ sender: UIButton) {
        peripheralsArray = []
        BLESerialManager.shared.rescan()
    }
    
    func startProgress() {
        progressHUD = MBProgressHUD.showAdded(to: self.view, animated: true)
        progressHUD.label.numberOfLines = 0
        progressHUD.label.text = "Connecting..."
        progressHUD.backgroundView.style = .solidColor;
        progressHUD.backgroundView.color = UIColor(white: 0.0, alpha: 0.1)
    }
    
    func stopProgress() {
        if let _ = progressHUD {
            progressHUD.hide(animated: true)
        }
    }
    
    func stopProgressWithError(_ errorMsg: String) {
        progressHUD.mode = .customView
        progressHUD.customView = UIImageView(image: #imageLiteral(resourceName: "error"))
        progressHUD.label.text = errorMsg
        progressHUD.hide(animated: true, afterDelay: 2.0)
    }
    
    // MARK: - Table view data source
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return peripheralsArray.count
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "peripheralCell", for: indexPath) as! PeripheralTableViewCell
        
        cell.peripheralNameLabel.text = "\(peripheralsArray[indexPath.row].peripheral.name ?? "Undefined") (\(peripheralsArray[indexPath.row].RSSI))"
        
        return cell
    }
    
    // MARK: - Table view delegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        startProgress()
        BLESerialManager.shared.connectToPeripheral(peripheralsArray[indexPath.row].peripheral)
    }
    
    // MARK: - BLESerialManagerDelegate
    
    func BLEDidDiscoverPeripheral(_ peripheral: CBPeripheral, RSSI: NSNumber?) {
        
        for addedPeripheral in peripheralsArray {
            if addedPeripheral.peripheral.identifier == peripheral.identifier {
                return
            }
        }
        peripheralsArray.append((peripheral: peripheral, RSSI: RSSI?.floatValue ?? 0.0 ))
    }
    
    func BLEDidConnectPeripheral(_ peripheral: CBPeripheral) {
        stopProgress()
        self.dismiss(animated: true, completion: nil)
    }
    
    func BLEDidFailToConnectPeripheral(_ peripheral: CBPeripheral, error: Error?) {
        stopProgressWithError("Connection failed, retry later")
    }
    
    func BLEDidReadRSSI(_ peripheral: CBPeripheral, RSSI: NSNumber) {
        if let row = peripheralsArray.index(where: {$0.peripheral.identifier == peripheral.identifier}) {
            peripheralsArray[row] = (peripheral: peripheral, RSSI: RSSI.floatValue )
        }
    }
    
}
