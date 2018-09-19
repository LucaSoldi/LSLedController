//
//  ViewController.swift
//  LSLedController
//
//  Created by Luca Soldi on 12/09/18.
//  Copyright © 2018 Luca Soldi. All rights reserved.
//

import UIKit
import HueKit
import CoreBluetooth

class ColorViewController: UIViewController, BLESerialManagerDelegate {

    @IBOutlet weak var colorSquarePicker: ColorSquarePicker!
    
    private var currentColor: UIColor!
    
    // the apa102 in arduino sketch has this max value for brightness
    private var maxBrightness = 31
    
    //default value of brightness
    private var brightnessValue = 10
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        BLESerialManager.shared.delegate = self
        
        didChangeColor(colorSquarePicker.color)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if BLESerialManager.shared.connectedPeripheral == nil && BLESerialManager.shared.lastPeripheralConnectedUUID == nil {
            self.performSegue(withIdentifier: "showPeripherals", sender: self)
        }
    }
    
    @IBAction func configButtonPressed(_ sender: UIButton) {
        BLESerialManager.shared.resetLastConnectionValues()
        self.performSegue(withIdentifier: "showPeripherals", sender: self)
    }
    @IBAction func colorBarPickerValueChanged(_ sender: ColorBarPicker) {
        colorSquarePicker.hue = sender.hue
        didChangeColor(colorSquarePicker.color)
    }
    
    @IBAction func colorSquarePickerValueChanged(_ sender: ColorSquarePicker) {
        didChangeColor(sender.color)
    }
    
    @IBAction func brightnessSliderValueChanged(_ sender: UISlider) {
        brightnessValue = Int(sender.value * Float(maxBrightness))
        sendColor(currentColor, brightness: brightnessValue)
    }
    
    func didChangeColor(_ color: UIColor) {
    
        currentColor = color
        
        guard let _ = BLESerialManager.shared.connectedPeripheral else {
            self.performSegue(withIdentifier: "showPeripherals", sender: self)
            return
        }

        sendColor(currentColor, brightness: brightnessValue)
        
    }
    
    func sendColor(_ color: UIColor, brightness: Int) {
        
        guard let rgbValue = color.rgbValue else {
            return
        }
        
        //format data to send
        let redByte = UInt8(UInt8(rgbValue.r*255))
        let greenByte = UInt8(UInt8(rgbValue.g*255))
        let blueByte = UInt8(UInt8(rgbValue.b*255))
        let brightByte = UInt8(UInt8(brightnessValue))
        
        BLESerialManager.shared.sendBytesToDevice([redByte, greenByte, blueByte, brightByte])
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    //MARK: BLESerialManagerDelegate
    func BLEDidDisconnectPeripheral(_ peripheral: CBPeripheral, error: Error?) {
        self.performSegue(withIdentifier: "showPeripherals", sender: self)
    }
    
}

