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
    
    var automat: AutomatCommunication = AutomatCommunication()
    
    
    
    
    
    //var connectionManager : NLAConnectionManager = NLAConnectionManager.sharedConnectionManager()
    @IBOutlet weak var PressureDisplay: UILabel!

    @IBOutlet weak var TempDisplay: UILabel!
    
    @IBAction func blink(_ sender: UIButton) {
        automat.blink()
    }

    
    // Create a dispatchQueue for the CentralManager. This executes tasks in serial
    let serialQueue = DispatchQueue(label: "queue")
    
    @IBOutlet weak var NoteDisplay: UILabel! = UILabel()
    
    
    @IBOutlet weak var StateDisplay: UILabel! = UILabel()
    
    @IBOutlet weak var AutomatDisplay: UILabel! = UILabel()


    
    
    

    
  /*  func hello(){
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
            self.PressureDisplay.text = "Pressure: \(String(describing: self.average)) Counts: \(self.storage.endIndex)"
        }
    }
    }*/
    /** StartSensors creates and registers a handler for the climate sensors, which prints out temperature and humidity on the screen
     */

    @IBAction func ReadData() {
        automat.readData()
    }
    func connectionInfoUpdate(notification note: Notification){
        StateDisplay.text = String(describing: note.object!)
    }
 
    func dataUpdate(notification note: Notification){
        PressureDisplay.text = "Pressure: \(String(describing:note.object!))"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        /*switch centralManager.state{
        case .poweredOn:
            StateDisplay.text = "Bluetooth: on"
            
        case .poweredOff:
            StateDisplay.text = "Bluetooth: off"
        default:
            StateDisplay.text = "State:unset -"
        }*/
        //automat.startScanningForAutomatDevices()
        NotificationCenter.default.addObserver(forName: Notification.Name(rawValue: "automatConnectionInfo"), object: nil, queue: OperationQueue.main, using: connectionInfoUpdate(notification:))
        
        NotificationCenter.default.addObserver(forName: Notification.Name(rawValue: "automatNewValue"), object: nil, queue: OperationQueue.main, using: dataUpdate(notification:))
        //NotificationCenter.default.addObserver(forName: Notification.Name(rawValue: "automatDeviceWasDiscovered"), object: nil, queue: OperationQueue.main, using: automatDiscovered(notification:))
        

        
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

