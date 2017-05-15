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
    var storage = [DataPoint]()
    //var connectionManager : NLAConnectionManager = NLAConnectionManager.sharedConnectionManager()

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
    }
    
     func automatDiscovered(notification note: Notification){
        
        
        //AutomatDisplay.text = "Automat connected: \(note.userInfo?["automatDeviceIdentifier"]! ?? "error")"
        
        automat.connectToDevice(withIdentifier: note.userInfo?["automatDeviceIdentifier"] as! String)
    
    }
    
    func handler(input: NLAAutomatDeviceData, error: NSError, completion: (_ result:String)-> Void){
        
        AutomatDisplay.text = "Something happened"

    }


    /*let handler: NLASensorHandler = (data: NLAAutomatDeviceData) -> Void{
        NotificationCenter.default.post(name: Notification.Name(rawValue: "testing"))
    }*/
    

    @IBAction func StartSensors() {
        let handler: NLASensorHandler = {(_ sensorData: NLAAutomatDeviceData?, _ error: Error?) -> Void in
            if error != nil{
                print("error")
            }else if self.chip != nil{
                self.AutomatDisplay.text = "Humidity: \(String(describing: self.chip!.climateData.humidity.decimalValue))"
                self.TempDisplay.text = "Temperature: \(String(describing: self.chip!.climateData.temperature.decimalValue))"
            }
            else{
                print("Chip is nil")
            }
        }
            chip?.registerClimateSensorHandler(handler)

    }
    
 //r handler = {(NLAAutomatDeviceData, Error?)-> Void in
        //print("hello")}
        
            
        
       /* NLASensorHandler:@escaping (NLAAutomatDeviceData, Error?)-> Void in {
        
        print("hey")})*/
        
            
            //chip!.registerClimateSensorHandler()
        
                
 
            //tempe = chip?.climateData.humidity.decimalValue
            //data = DataPoint(temperature: (chip?.climateData.temperature.decimalValue)!, time: Date())
            //storage[storage.endIndex+1] = data!
    
    
    
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
        
        NotificationCenter.default.addObserver(forName: Notification.Name(rawValue: "testing"), object: nil, queue: OperationQueue.main, using: automatDiscovered(notification:))
        
        
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

