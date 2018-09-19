//
//  BLESerialManager.swift
//  LSLedController
//
//  Created by Luca Soldi on 12/09/18.
//  Copyright © 2018 Luca Soldi. All rights reserved.
//

import Foundation
import CoreBluetooth

@objc protocol BLESerialManagerDelegate {
    
    @objc optional func BLEUpdateCentralManagerState(_ state: CBManagerState)
    @objc optional func BLEDidDiscoverPeripheral(_ peripheral: CBPeripheral, RSSI: NSNumber?)
    @objc optional func BLEDidReadRSSI(_ peripheral: CBPeripheral, RSSI: NSNumber)
    @objc optional func BLEDidDisconnectPeripheral(_ peripheral: CBPeripheral, error: Error?)
    @objc optional func BLEDidFailToConnectPeripheral(_ peripheral: CBPeripheral, error: Error?)
    @objc optional func BLEDidConnectPeripheral(_ peripheral: CBPeripheral)
    
}

class BLESerialManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    static let shared = BLESerialManager()

    var delegate: BLESerialManagerDelegate?
    
    var centralManager: CBCentralManager!
    
    var lastPeripheralConnectedUUID : String!
    var connectedPeripheral: CBPeripheral?
    
    var serviceUUID: CBUUID?
    
    var characteristicUUID: CBUUID?
    
    var writeCharacteristic: CBCharacteristic?
    
    let startPacketIndicator: UInt8 = 85            // 10101010
    let endPacketIndicator: UInt8 = 170             // 01010101
    let timeBetweenPackets = 0.2                    // 200 ms
    var canSendPacket = true
    
    let defaults = UserDefaults.standard

    var isReady: Bool {
        get {
            return centralManager.state == .poweredOn && connectedPeripheral != nil
        }
    }
    
    // legit HM10   -> .withoutResponse
    // fake HM10    -> .withResponse
    private var characteristicWriteType: CBCharacteristicWriteType = .withoutResponse
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        lastPeripheralConnectedUUID = defaults.object(forKey: "lastConnectedPeripheralUUID") as? String
        if let lastServiceUUID = defaults.object(forKey: "lastServiceUUID") as? String {
            serviceUUID = CBUUID(string: lastServiceUUID)
        }
        if let lastCharacteristicUUID = defaults.object(forKey: "lastCharacteristicUUID") as? String {
            characteristicUUID = CBUUID(string: lastCharacteristicUUID)
        }
    }
    
    func resetLastConnectionValues() {
        lastPeripheralConnectedUUID = nil
    }
    
    func startScan () {
        guard let _ = serviceUUID else {
            return
        }
        guard let _ = characteristicUUID else {
            return
        }
        startScanPeripheralWithService(serviceUUID, characteristic: characteristicUUID)
    }
    
    func startScanPeripheralWithService(_ service: CBUUID!, characteristic: CBUUID!) {
        
        serviceUUID = service
        characteristicUUID = characteristic
    
        //check if central manager is powered on
        guard centralManager.state == .poweredOn else {
            return
        }
    
        centralManager.scanForPeripherals(withServices: [serviceUUID!], options: nil)
        
        // get peripherals already connected
        let peripherals = centralManager.retrieveConnectedPeripherals(withServices: [serviceUUID!])
        for peripheral in peripherals {
            //read RSSI through delegate -> readRSSI;
            delegate?.BLEDidDiscoverPeripheral!(peripheral, RSSI: nil)
            peripheral.readRSSI()
        }
    }
    
    func stopScan() {
        centralManager.stopScan()
    }
    
    func rescan() {
        stopScan()
        startScan()
    }
    
    func connectToPeripheral(_ peripheral: CBPeripheral) {
        centralManager.connect(peripheral, options: nil)
    }
    
    func sendBytesToDevice(_ bytes: [UInt8]) {
        guard isReady else {
            return
        }
        guard canSendPacket else {
            return
        }
        guard connectedPeripheral != nil else {
            return
        }
        
        canSendPacket = false
        var defData = [startPacketIndicator]
        defData += bytes
        defData.append(endPacketIndicator)
        
        let data = Data(bytes: UnsafePointer<UInt8>(defData), count: defData.count)
        connectedPeripheral!.writeValue(data, for: writeCharacteristic!, type: characteristicWriteType)
        Timer.scheduledTimer(withTimeInterval: timeBetweenPackets, repeats: false) { (_) in
            self.canSendPacket = true
        }
    }
        
    //MARK: CBCentralManagerDelegate
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOff:
            print("BLE Powered Off")
        case .poweredOn:
            print("BLE Powered On")
            //reconnect if powered on
            if (connectedPeripheral != nil) {
                connectToPeripheral(connectedPeripheral!)
            }
            else {
                startScan()
            }
        case .unsupported,
             .resetting,
             .unauthorized,
             .unknown:
            print("Unexpected CBCentralManager State")
            fallthrough
        default:
            break;
        }
        
        return;
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        if peripheral.identifier.uuidString == lastPeripheralConnectedUUID {
            connectedPeripheral = peripheral
            connectToPeripheral(peripheral)
        }
        delegate?.BLEDidDiscoverPeripheral?(peripheral, RSSI: RSSI)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        guard let _ = serviceUUID else {
            return
        }
        peripheral.discoverServices([serviceUUID!])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectedPeripheral = nil
        resetLastConnectionValues()
        delegate?.BLEDidDisconnectPeripheral?(peripheral, error: error)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectedPeripheral = nil
        resetLastConnectionValues()
        delegate?.BLEDidFailToConnectPeripheral?(peripheral, error: error)
    }
    
    //MARK: CBPeripheralDelegate
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let _ = characteristicUUID else {
            return
        }
        //discovered peripheral with specified service
        for service in peripheral.services! {
            peripheral.discoverCharacteristics([characteristicUUID!], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {

        guard let _ = characteristicUUID else {
            return
        }
        
        for characteristic in service.characteristics! {
            if characteristic.uuid == characteristicUUID {
                // save reference of the characteristic
                writeCharacteristic = characteristic
                
                characteristicWriteType = characteristic.properties.contains(.write) ? .withResponse : .withoutResponse
                
                // save the last peripheral connected
                defaults.set(peripheral.identifier.uuidString, forKey: "lastConnectedPeripheralUUID")
                defaults.set(serviceUUID?.uuidString, forKey: "lastServiceUUID")
                defaults.set(characteristicUUID?.uuidString, forKey: "lastCharacteristicUUID")
                // device is ready to receive data
                delegate?.BLEDidConnectPeripheral?(peripheral)
                connectedPeripheral = peripheral
            }
        }
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        delegate?.BLEDidReadRSSI?(peripheral, RSSI: RSSI)
    }
    
    
}
