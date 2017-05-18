//
//  AutomatCommunication.swift
//  bluetooth sensor
//
//  Created by Anton on 2017-05-10.
//  Copyright © 2017 Anton. All rights reserved.
//

import Foundation
//import bluetooth
import NeueLabsAutomat


class AutomatCommunication {
    var timer: Timer?
    let automat = NLAConnectionManager()
    var centralManager : CBCentralManager!
    var chip: NLABaseBoard?
    var device : NLAAutomatDevice?
    var average : Decimal?
    var storage: [DataPoint] = []
    var data: UInt8?
    let pointerToStartCommand = UnsafeMutablePointer<UInt8>.allocate(capacity: 2)
    var dig_T: [UInt16]! = [UInt16]()
    var dig_T1: UInt16?
    var dig_T2: UInt16?
    var dig_T3: UInt16?
    var dig_P: [UInt16]! = [UInt16]()
    var dig_P1: UInt16?
    var dig_P2: UInt16?
    var dig_P3: UInt16?
    var dig_P4: UInt16?
    var dig_P5: UInt16?
    var dig_P6: UInt16?
    var dig_P7: UInt16?
    var dig_P8: UInt16?
    var dig_P9: UInt16?
    var temperature: Int32?
    init() {
        startConnection()
        pointerToStartCommand.initialize(from: [0xF4, 0b11100001])
    }
    
    func startConnection()-> Void{
        automat.startScanningForAutomatDevices()
        NotificationCenter.default.addObserver(forName: Notification.Name(rawValue: "automatDeviceDidConnect"), object: nil, queue: OperationQueue.main, using:automatConnected(notification:))
        
        NotificationCenter.default.addObserver(forName: Notification.Name(rawValue: "automatDeviceWasDiscovered"), object: nil, queue: OperationQueue.main, using: automatDiscovered(notification:))
    }
    
    
    func blink()-> Void{
        if chip != nil {
            let blinkSequence = NLADigitalBlinkSequence()
            blinkSequence.nrOfBlinks = 20
            blinkSequence.outputPeriod = 100
            blinkSequence.outputRatio = 50
            blinkSequence.addDigitalPort(NLABaseBoardIOPort.blueLED)
            chip!.write(blinkSequence)
        }
    }
    
    
    /**
     * Connects to the baseboard of the automat device, and calls the method which starts the sensors
     *
     * @param notification: the notification that triggered the method
     **/
    func automatConnected(notification note: Notification){
        device = automat.automatDevice(withIdentifier: note.userInfo?["automatDeviceIdentifier"] as! String)
        if device != nil {
            NotificationCenter.default.post(name: Notification.Name(rawValue: "automatConnectionInfo"), object: "Automat Connected")
        }else{
            NotificationCenter.default.post(name: Notification.Name(rawValue: "automatConnectionInfo"), object: "Automat connection error")
        }
        
        chip = automat.automatDevice(withIdentifier: note.userInfo?["automatDeviceIdentifier"] as! String) as? NLABaseBoard
        
        StartSensors()
    }
    
    
    /**If an automatDeviceWasDiscovered notification is received, execute automatDiscovered method
     * This method connects to the automat device using a unique identifier found in the Dictionary contained in the notification
     *
     * @param notification: the notification that triggered the method
     */
    func automatDiscovered(notification note: Notification){
        automat.connectToDevice(withIdentifier: note.userInfo?["automatDeviceIdentifier"] as! String)
    }
    
    
    func StartSensors() {
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
                self.average = sum/(Decimal(self.storage.endIndex))
                
                NotificationCenter.default.post(name: Notification.Name(rawValue: "automatNewValue"), object: String(describing:
                    self.average!))
                
            }
        } //Slut handler
        chip?.registerClimateSensorHandler(handler)
        
        
        let writeHandler: NLAI2CWriteHandler = {(_ writeData: NLAI2CWriteData?, _ error: Error?) -> Void in
            if error != nil{
                print("error")
            }else{
                print("Wrote stuff to reset")
            }
        }
        
        let idHandler: NLAI2CReadHandler = {(_ responseData: NLAI2CReadResponseData?, _ error: Error?) -> Void in
            if error != nil{
                print("error")
            }else{
                print("Id: \(responseData!.responses![0])")
            }
        }
        
        let reset: NLAI2CMutableWriteData = NLAI2CMutableWriteData.init(address: 0x76)
        reset.addI2CCommand(0xE0)
        
        
        chip!.writeI2CCommand(reset, withHandler: writeHandler)
        let getId: NLAI2CMutableReadData = NLAI2CMutableReadData.init(address: 0x76, expectedResponseLength: 1)
        getId.addI2CCommand(0xD0)
        chip!.readI2CCommand(getId, withHandler: idHandler)
        
        
        
        let calibrationParameterHandler: NLAI2CReadHandler = {(_ responseData: NLAI2CReadResponseData?, _ error: Error?) -> Void in
            if error != nil{
                print("error")
            }else{
                
                self.dig_T.append(UInt16(((UInt16((responseData!.responses[1] as! UInt8)))<<8)|UInt16(responseData!.responses[0] as! UInt8)))
                self.dig_T.append(UInt16(((UInt16((responseData!.responses[3] as! UInt8)))<<8)|UInt16(responseData!.responses[2] as! UInt8)))
                self.dig_T.append(UInt16(((UInt16((responseData!.responses[5] as! UInt8)))<<8)|UInt16(responseData!.responses[4] as! UInt8)))
                
                
                /*
                 print("calib lsb: \(responseData!.responses[2] as! UInt8)")
                 print("calib msb: \(responseData!.responses[3] as! UInt8)")
                 print("calib converted: \(self.dig_T[1])")
                 print("val: \(((UInt16((responseData!.responses[3] as! UInt8)))<<8))")*/
            }
        }
        let calib: NLAI2CMutableReadData = NLAI2CMutableReadData.init(address: 0x76, expectedResponseLength: 6)
        calib.addI2CCommand(0x88)
        chip!.readI2CCommand(calib, withHandler: calibrationParameterHandler)
        
    }
    func readData()-> Void{
        if chip != nil{
            let readHandler: NLAI2CReadHandler = {(_ responseData: NLAI2CReadResponseData?, _ error: Error?) -> Void in
                if error != nil{
                    print("error")
                }else{
                    var data: [Int8] = [Int8]()
                    data.append(responseData!.responses![0] as! Int8)
                    data.append(responseData!.responses![1] as! Int8)
                    data.append(responseData!.responses![2] as! Int8)
                    
                    print("\(type(of:responseData!.responses[0]))")
                    self.temperature = Int32((((UInt32((responseData!.responses[0] as! UInt8)))<<12)) | ((UInt32((responseData!.responses[1] as! UInt8)))<<4)|(UInt32(responseData!.responses[2] as! UInt8)>>4))
                    
                    
                    //let value: Int32 = (((Int32(data[0])<<12)|(Int32(data[1])<<4)|(Int32(data[2])<<4)))
                    
                    //print("Read temp: \(temperature) MSB: \(Int32(data[0])<<12)   LSB: \(Int32(data[1])<<4) XLSB: \(Int32(data[2])<<4)")
                    
                    print("Actual temp: \(self.compensateTemperatureMeasurement(self.temperature!))")
                }
            }
            let newMeasurement: NLAI2CMutableWriteData! = NLAI2CMutableWriteData.init(address: 0x76)
            
            newMeasurement.addI2CCommands(pointerToStartCommand, count: 2)
            
            chip!.writeI2CCommand(newMeasurement, withHandler: {(_ writeData: NLAI2CWriteData?, _ error: Error?) -> Void in
                if error != nil{
                    print("error performing new measurement")
                }else{
                }
            } )
            let most: NLAI2CMutableReadData = NLAI2CMutableReadData.init(address: 0x76, expectedResponseLength: 3)


            
            most.addI2CCommand(0xFA)
            chip?.readI2CCommand(most, withHandler: readHandler)
            
            
            
            
        }
        else{
            print("Chip not set yet")
        }
        
        
        
    }
    
    func compensateTemperatureMeasurement(_ temp: Int32) -> Int16{
        var ret: Int16?
        var x1: Int32?
        var x2: Int32?
        
        x1 = ((((temp >> 3)-(Int32(dig_T[0])<<1))) * (Int32(dig_T[2]))) >> 11
        
        x2 = (((((temp >> 4) - (Int32(dig_T[0]))) * ((temp>>4)-(Int32(dig_T[0]))))>>12)*(Int32(dig_T[2]))) >> 14
        let a = (x1! + x2!)
        //ret = (a * 5 + 128)
        
        ret = Int16(((((a)*25)+128)>>8))
        
        
        return ret!
    }
}
