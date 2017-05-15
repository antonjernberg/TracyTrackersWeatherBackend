//
//  ViewController.swift
//  bluetooth sensor
//
//  Created by Anton on 2017-05-10.
//  Copyright © 2017 Anton. All rights reserved.
//

import UIKit
import CoreBluetooth
import NeueLabsAutomat
import Foundation


class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate	{
    
    var centralManager : CBCentralManager!
    var connectingPeripheral : CBPeripheral!
    let automat = NLAConnectionManager()
    var chip: NLABaseBoard?
    var device : NLAAutomatDevice?
    var average : Decimal?
    var storage: [DataPoint] = []
    //var connectionManager : NLAConnectionManager = NLAConnectionManager.sharedConnectionManager()
    @IBOutlet weak var PressureDisplay: UILabel!

    @IBOutlet weak var TempDisplay: UILabel!
    
    @IBAction func blink(_ sender: UIButton) {
        if chip != nil {
            StateDisplay.text = "Chip är satt"
            let blinkSequence = NLADigitalBlinkSequence()
            blinkSequence.nrOfBlinks = 5
            blinkSequence.outputPeriod = 1000
            blinkSequence.outputRatio = 50
            blinkSequence.addDigitalPort(NLABaseBoardIOPort.blueLED)
           
            
            chip!.write(blinkSequence)
        }
    }

    // Create a dispatchQueue for the CentralManager. This executes tasks in serial
    let serialQueue = DispatchQueue(label: "queue")
    
    @IBOutlet weak var NoteDisplay: UILabel! = UILabel()
    
    
    @IBOutlet weak var StateDisplay: UILabel! = UILabel()
    
    @IBOutlet weak var AutomatDisplay: UILabel! = UILabel()
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder:  aDecoder)
        centralManager = CBCentralManager(delegate: self, queue: serialQueue)
    }
    
    /**
    * Connects to the baseboard of the automat device, and calls the method which starts the sensors
    *
    **/
    func automatConnected(notification note: Notification){
        NoteDisplay.text = "Notification: \(note.name.rawValue)"
        
        device = automat.automatDevice(withIdentifier: note.userInfo?["automatDeviceIdentifier"] as! String)
        if device != nil {
            StateDisplay.text = "Device satt"
        }else{
            StateDisplay.text = "Device ej satt"
        }
        
        chip = automat.automatDevice(withIdentifier: note.userInfo?["automatDeviceIdentifier"] as! String) as? NLABaseBoard
        
        chip?.startClimateSensor(withReadoutRate: 500)
        StartSensors()
    }
    
    
    /**If an automatDeviceWasDiscovered notification is received, execute automatDiscovered method
    * This method connects to the automat device that was found, using a unique identifier found in the Dictionary contained in the notification
    */
     func automatDiscovered(notification note: Notification){
        automat.connectToDevice(withIdentifier: note.userInfo?["automatDeviceIdentifier"] as! String)
    
    }
    
    func hello(){
        //Tänkt att vara en handler som tar ut average av existerande data
    let handler: NLASensorHandler = {(_ sensorData: NLAAutomatDeviceData?, _ error: Error?) -> Void in
        if error != nil{
            print("error")
        }else{
            
            self.storage.append(DataPoint(temperature: (self.chip?.climateData.temperature.decimalValue)!, time: Date()))
            var sum: Decimal = 0.0
            for var i in self.storage
            {
                sum = sum + i.temperature
            }
            self.average = sum/(Decimal(self.storage.endIndex+1))
            self.PressureDisplay.text = "Pressure: \(String(describing: self.average))"
        }
    }
    }
    /** StartSensors creates and registers a handler for the climate sensors, which prints out temperature and humidity on the screen
     */
    @IBAction func StartSensors() {
        let handler: NLASensorHandler = {(_ sensorData: NLAAutomatDeviceData?, _ error: Error?) -> Void in
            if error != nil{
                print("error")
            }else if self.chip != nil{
                self.AutomatDisplay.text = "Humidity: \(String(describing: self.chip!.climateData.humidity.decimalValue))%"
                self.TempDisplay.text = "Temperature: \(String(describing: self.chip!.climateData.temperature.decimalValue))"
            }
            else{
                print("Chip is nil")
            }
        }
            chip?.registerClimateSensorHandler(handler)

    }
    
 
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        switch centralManager.state{
        case .poweredOn:
            StateDisplay.text = "Bluetooth: on"
            
        case .poweredOff:
            StateDisplay.text = "Bluetooth: off"
        default:
            StateDisplay.text = "State:unset -"
        }
        automat.startScanningForAutomatDevices()
        NotificationCenter.default.addObserver(forName: Notification.Name(rawValue: "automatDeviceDidConnect"), object: nil, queue: OperationQueue.main, using: automatConnected(notification:))
        
        NotificationCenter.default.addObserver(forName: Notification.Name(rawValue: "automatDeviceWasDiscovered"), object: nil, queue: OperationQueue.main, using: automatDiscovered(notification:))
        

        
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        StateDisplay.text = "Device connected: \(peripheral.name!)"
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
       print("State update")
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

