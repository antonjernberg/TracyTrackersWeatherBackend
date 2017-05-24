//
//  AutomatCommunication.swift
//  bluetooth sensor
//
//  Created by Anton on 2017-05-10.
//  Copyright © 2017 Anton. All rights reserved.
//

import Foundation
import NeueLabsAutomat


class AutomatCommunication {
    // A timer used to continuously update pressure every 30 min
    var timer: Timer?
    var timerForCountingAverage: Timer?
    var arrayForCountingAverage: [Double]?
    
    // An object representing a connection manager used to connect with the Automat board
    let automatConnectionManager = NLAConnectionManager()
    
    // An object representing the Automat baseboard. Provides access to the functionality of the Automat board
    var automatBaseboard: NLABaseBoard?
    var automatDevice : NLAAutomatDevice?
    var averageChangeOfPressurePerHour : Double? = 0.0
    
    // A local array for storing DataPoints
    var pressureStorage: [DataPoint]!
    
    // Pointers to UInt8 arrays containing commands for writing to the registers of a BME280 sensor
    let pointerToStartSensorCommand = UnsafeMutablePointer<UInt8>.allocate(capacity: 2)
    let pointerToStartFilterCommand = UnsafeMutablePointer<UInt8>.allocate(capacity: 2)
    let pointerToStartResetCommand = UnsafeMutablePointer<UInt8>.allocate(capacity: 2)
    
    
    // Variables for storing Calibration Parameters from the BME280 sensor
    // Do not access these before the sensors have been started
    var T1: UInt16!
    var T2: Int16!
    var T3: Int16!
    var P1: UInt16!
    var P2: Int16!
    var P3: Int16!
    var P4: Int16!
    var P5: Int16!
    var P6: Int16!
    var P7: Int16!
    var P8: Int16!
    var P9: Int16!
    
    // A value used for compensating pressure and humidity. It is calculated when compensating temperature
    var t_fine: Int32 = 0
    
    
    // An enum representing each weather forecast
    enum Weather {
        case notStable
        case goodWeather
        case stable
        case rainy
        case thunderStorm
        case rain
    }
    
    
    
    
    /**
     * Starts up the local storage, initiates constants, and attempts to connect to a nearby Automat
     *
     **/
    init() {
        startAutomatConnection()
        pointerToStartSensorCommand.initialize(from: [0xF4, 0b00100101])
        pointerToStartFilterCommand.initialize(from: [0xF5, 0b00000000])
        pointerToStartResetCommand.initialize(from: [0xE0, 0xB6])
        
        if (isKeyPresentInUserDefaults(key: "pressureStorageTracyRain")){
            if let data = UserDefaults.standard.data(forKey: "pressureStorageTracyRain"), let temporaryPressureStorage = NSKeyedUnarchiver.unarchiveObject(with:data) as? [DataPoint]{
                self.pressureStorage = temporaryPressureStorage
            }
            else{
                pressureStorage = [DataPoint]()
                storePressureStorage()
            }
        }
        else{
            pressureStorage = [DataPoint]()
            storePressureStorage()
        }
    }
    
    /**
     *   Check if an object with the entered key has been stored locally using UserDefaults
     *
     *   @param key : the KEY for the object in UserDefaults
     *   @return a Bool telling wether or not AN object has been stored with KEY
     **/
    private func isKeyPresentInUserDefaults(key: String) -> Bool{
        return UserDefaults.standard.value(forKey: "pressureStorageTracyRain") != nil
    }
    
    /**
     * A method that encodes PressureStorage and stores it in UserDefaults
     */
    private func storePressureStorage(){
        let encodedData = NSKeyedArchiver.archivedData(withRootObject: self.pressureStorage)
        UserDefaults.standard.setValue(encodedData, forKey: "pressureStorageTracyRain")
        UserDefaults.standard.synchronize()
    }
    
    
    
    /**
     *   Starts attempts to communicate with an Automat board.
     *   Observers are set to listen to Notifications stating that an Automat device was Discovered and/or connected
     **/
    private func startAutomatConnection()-> Void{
        automatConnectionManager.startScanningForAutomatDevices()
        NotificationCenter.default.addObserver(forName: Notification.Name(rawValue: "automatDeviceDidConnect"), object: nil, queue: OperationQueue.main, using:automatConnected(notification:))
        
        NotificationCenter.default.addObserver(forName: Notification.Name(rawValue: "automatDeviceWasDiscovered"), object: nil, queue: OperationQueue.main, using: automatDiscovered(notification:))
    }
    
    /**
     * Connects to the baseboard of the automat device, and calls the method which starts the sensors
     *
     * @param notification: the notification that triggered the method
     **/
    private func automatConnected(notification note: Notification){
        automatDevice = automatConnectionManager.automatDevice(withIdentifier: note.userInfo?["automatDeviceIdentifier"] as! String)
        
        if automatDevice != nil {
            NotificationCenter.default.post(name: Notification.Name(rawValue: "automatConnectionInfo"), object: "Automat Connected")
        }else{
            NotificationCenter.default.post(name: Notification.Name(rawValue: "automatConnectionInfo"), object: "Automat connection error")
        }
        automatBaseboard = automatConnectionManager.automatDevice(withIdentifier: note.userInfo?["automatDeviceIdentifier"] as! String) as? NLABaseBoard
        
        StartSensors()
    }
    
    
    
    /**If an automatDeviceWasDiscovered notification is received, execute automatDiscovered method
     * This method connects to the automat device using a unique identifier found in the Dictionary contained in the notification
     *
     * @param notification: the notification that triggered the method
     */
    private func automatDiscovered(notification note: Notification){
        automatConnectionManager.connectToDevice(withIdentifier: note.userInfo?["automatDeviceIdentifier"] as! String)
    }
    
    
    private func StartSensors() {
        let writeHandler: NLAI2CWriteHandler = {(_ writeData: NLAI2CWriteData?, _ error: Error?) -> Void in
            if error != nil{
                print("error")
            }else{
                print("Wrote stuff to reset")
            }
        }
        
        let reset: NLAI2CMutableWriteData = NLAI2CMutableWriteData.init(address: 0x76)
        reset.addI2CCommands(pointerToStartResetCommand, count: 2)
        
        
        automatBaseboard!.writeI2CCommand(reset, withHandler: writeHandler)
        
        
        // The handler used to store the fetched calibration parameters for TEMPERATURE (T1 - T3)
        let temperatureCalibrationParameterHandler: NLAI2CReadHandler = {(_ responseData: NLAI2CReadResponseData?, _ error: Error?) -> Void in
            if error != nil{
                print("error")
            }else{
                var a_data_u8 = responseData!.responses!
                
                self.T1 = UInt16((UInt16((a_data_u8[1] as! UInt8)) << 8) | UInt16(a_data_u8[0] as! UInt8))
                self.T2 = Int16((Int16((a_data_u8[3] as! Int8)) << 8) | Int16(a_data_u8[2] as! Int8))
                self.T3 = Int16((Int16((a_data_u8[5] as! Int8)) << 8) | Int16(a_data_u8[4] as! Int8))
            }
        }
        
        
        // The handler used to store the fetched calibration parameters for PRESSURE (P1 - P9)
        let pressureCalibrationParameterHandler: NLAI2CReadHandler = {(_ responseData: NLAI2CReadResponseData?, _ error: Error?) -> Void in
            if error != nil{
                print("error")
            }else{
                var a_data_u8 = responseData!.responses!
                
                
                self.P1 = UInt16((UInt16((a_data_u8[1] as! UInt8)) << 8) | UInt16(a_data_u8[0] as! UInt8))
                print("P1 : \(self.P1)")
                self.P2 = Int16((Int16((a_data_u8[3] as! Int8)) << 8) | Int16(a_data_u8[2] as! Int8))
                print("P2 : \(self.P2)")
                self.P3 = Int16((Int16((a_data_u8[5] as! Int8)) << 8) | Int16(a_data_u8[4] as! Int8))
                print("P3 : \(self.P3)")
                self.P4 = Int16((Int16((a_data_u8[7] as! Int8)) << 8) | Int16(a_data_u8[6] as! Int8))
                print("P4 : \(self.P4)")
                self.P5 = Int16((Int16((a_data_u8[9] as! Int8)) << 8) | Int16(a_data_u8[8] as! Int8))
                self.P6 = Int16((Int16((a_data_u8[11] as! Int8)) << 8) | Int16(a_data_u8[10] as! Int8))
                self.P7 = Int16((Int16((a_data_u8[13] as! Int8)) << 8) | Int16(a_data_u8[12] as! Int8))
                self.P8 = Int16((Int16((a_data_u8[15] as! Int8)) << 8) | Int16(a_data_u8[14] as! Int8))
                self.P9 = Int16((Int16((a_data_u8[17] as! Int8)) << 8) | Int16(a_data_u8[17] as! Int8))
            }
        }
        
        let startFilter: NLAI2CMutableWriteData = NLAI2CMutableWriteData.init(address: 0x76)
        startFilter.addI2CCommands(pointerToStartFilterCommand, count: 2)
        
        automatBaseboard!.writeI2CCommand(startFilter, withHandler: writeHandler)
        
        let calibTemp: NLAI2CMutableReadData = NLAI2CMutableReadData.init(address: 0x76, expectedResponseLength: 6)
        let calibPress: NLAI2CMutableReadData = NLAI2CMutableReadData.init(address: 0x76, expectedResponseLength: 18)
        
        calibTemp.addI2CCommand(0x88)
        calibPress.addI2CCommand(0x8D)
        automatBaseboard!.readI2CCommand(calibTemp, withHandler: temperatureCalibrationParameterHandler)
        automatBaseboard!.readI2CCommand(calibPress, withHandler: pressureCalibrationParameterHandler)
        timer = Timer.scheduledTimer(timeInterval: 70, target: self, selector: #selector(startMeasurementCycle), userInfo: nil, repeats: true)
        sleep(1)
        startMeasurementCycle()
        
    }
    @objc func startMeasurementCycle(){
        arrayForCountingAverage = [Double]()
        timerForCountingAverage = Timer.scheduledTimer(timeInterval: 10, target: self, selector: #selector(newMeasurement), userInfo: nil, repeats: true)
    }
    
    
    @objc private func newMeasurement(){
        if(arrayForCountingAverage == nil){
            arrayForCountingAverage = [Double]()
        }
        readData()
        sleep(1)
        if(arrayForCountingAverage!.endIndex >= 4){
            
            timerForCountingAverage?.invalidate()
            var sum: Double! = 0.0
            for var i in self.pressureStorage
            {
                if(i.time.timeIntervalSinceNow < (-7200)){
                    self.pressureStorage.removeFirst()
                    print("removed a value")
                } else{
                    break
                }
            }
            for var i in arrayForCountingAverage!
            {
                sum = sum + i
            }
            pressureStorage.append(DataPoint(pressure: (sum/Double(arrayForCountingAverage!.endIndex)), time: Date()))
            
            // If less than half an hour (1800) has passed since the first DataPoint, do not calculate a new average.
            if(self.pressureStorage.last != nil){
                let first = self.pressureStorage.first!
                if (first.time.timeIntervalSinceNow < (-1800)){  // 1800 = 30 min 900 = 15 min
                    let last = self.pressureStorage.last!
                    // (Pressure difference) / ((Seconds between first and last measurement) / 3600)
                    self.averageChangeOfPressurePerHour = ((last.pressure/100) - (first.pressure/100)) / ((-(first.time.timeIntervalSinceNow - last.time.timeIntervalSinceNow)) / 3600)
                }
                else{
                    print("Too little time has passed since the first temperature measurement was made")
                    self.averageChangeOfPressurePerHour = nil
                }
            }
            // Check if pressure change is enough to cause a new weather prediction.
            // Throws Nofications with name newWeatherForecast containing a weather prediction
            if(self.averageChangeOfPressurePerHour != nil && pressureStorage.endIndex > 1){
                let avg = self.averageChangeOfPressurePerHour
                print("Checking weather forecast. Average change: \(avg!)")
                if(avg! >= 2.5){
                    NotificationCenter.default.post(name: Notification.Name(rawValue: "newWeatherForecast"), object: Weather.notStable)
                    //not stable
                }
                else if(2.5 > avg! && avg! > 0.5){
                    NotificationCenter.default.post(name: Notification.Name(rawValue: "newWeatherForecast"), object: Weather.goodWeather)
                    //stable good
                }
                else if(avg! >= -0.5 && avg! <= 0.5){
                    NotificationCenter.default.post(name: Notification.Name(rawValue: "newWeatherForecast"), object: Weather.stable)
                    //stable
                }
                else if(avg! > -2.5 && avg! < -0.5){
                    NotificationCenter.default.post(name: Notification.Name(rawValue: "newWeatherForecast"), object: Weather.rainy)
                    //stablerainy
                }
                else if(avg! <= -2.5){
                    NotificationCenter.default.post(name: Notification.Name(rawValue: "newWeatherForecast"), object: Weather.thunderStorm)
                    //thunderstorm
                }
            }
            self.storePressureStorage()
        }
    }
    
    
    
    /**
     * Reads new measurements from the BME280 sensor by reading register, and stores it in PressureStorage
     *
     **/
    private func readData()-> Void{
        if automatBaseboard != nil{
            let readTemperateAndPressureHandler: NLAI2CReadHandler = {(_ responseData: NLAI2CReadResponseData?, _ error: Error?) -> Void in
                if error != nil{
                    print("error")
                }else{
                    var data: [UInt8] = [UInt8]()
                    data.append(responseData!.responses![0] as! UInt8)  // MSB pressure
                    data.append(responseData!.responses![1] as! UInt8)  // LSB pressure
                    data.append(responseData!.responses![2] as! UInt8)  // XLSB pressure
                    data.append(responseData!.responses![3] as! UInt8)  // MSB temperature
                    data.append(responseData!.responses![4] as! UInt8)  // LSB temperature
                    data.append(responseData!.responses![5] as! UInt8)  // XLSB temperature
                    
                    
                    // Shift bits and store as a single signed 32 bit Integer
                    let pressure: Int32! = Int32((((UInt32((responseData!.responses[0] as! UInt8)))<<12)) | ((UInt32((responseData!.responses[1] as! UInt8)))<<4)|(UInt32(responseData!.responses[2] as! UInt8)>>4))
                    
                    
                    let temperature : Int32! = Int32((((UInt32((responseData!.responses[3] as! UInt8)))<<12)) | ((UInt32((responseData!.responses[4] as! UInt8)))<<4)|(UInt32(responseData!.responses[5] as! UInt8)>>4))
                    
                    
                    // Temperature has to be calculated, but is not needed for weather forecasting, it is therefore only printed to console
                    print("Temperature: \(self.compensateTemperatureMeasurement(temperature))")
                    
                    
                    let newPressure = self.compensatePressureMeasurement(pressure)
                    print("Pressure: \(newPressure) Pressure divided by 256: \(newPressure/256)")
                    if(self.arrayForCountingAverage != nil){
                        self.arrayForCountingAverage!.append(Double(newPressure))
                    }
                }
            }
            let newMeasurement: NLAI2CMutableWriteData! = NLAI2CMutableWriteData.init(address: 0x76)
            
            newMeasurement.addI2CCommands(pointerToStartSensorCommand, count: 2)
            automatBaseboard!.writeI2CCommand(newMeasurement, withHandler: {(_ writeData: NLAI2CWriteData?, _ error: Error?) -> Void in
                if error != nil{
                    print("Error performing new measurement")
                }
            }
            )
            
            let readTemperatureAndPressure: NLAI2CMutableReadData = NLAI2CMutableReadData.init(address: 0x76, expectedResponseLength: 6)
            readTemperatureAndPressure.addI2CCommand(0xF7)
            automatBaseboard?.readI2CCommand(readTemperatureAndPressure, withHandler: readTemperateAndPressureHandler)
        }
        else{
            print("Chip not set yet")
        }
    }
    
    
    
    /**
     *   Compensates the temperature value received from the BME280 sensor using calibration parameters received from the sensor.
     *
     *   @param uncomp : the uncompensated temperature value read directly from the sensor
     *   @return : the compensated value of the temperature as signed Int16.
     **/
    private func compensateTemperatureMeasurement(_ uncomp: Int32) -> Double                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             {
        /*  DOUBLE COMPENSATION FORMULA returns Double*/
        
        var x1 : Double = 0
        var x2 : Double = 0
        var comp : Double = 0
        
        x1 = ((Double(uncomp))/16384.0 - (Double(T1))/1024.0) * (Double(T2))
        x2 = (((Double(uncomp))/131072.0 - (Double(T1))/8192.0) * ((Double(uncomp))/131072.0 - (Double(T1))/8192.0)) * (Double(T3))
        t_fine = Int32(x1 + x2)
        comp = (x1 + x2) / 5120.0
        return comp
        
        
        
        
        /* 32 - BIT COMPENSATION FORMULA returns Int32*/
        /*
         var comp: Int32 = 0
         var x1: Int32 = 0
         var x2: Int32 = 0
         
         // calculate x1
         x1 = ((((uncomp >> 3) - (Int32(T1)<<1))) * (Int32(T2))) >> 11
         
         // calculate x2
         x2 = (((((uncomp >> 4) - (Int32(T1))) * ((uncomp>>4) - (Int32(T1)))) >> 12) * (Int32(T3))) >> 14
         
         t_fine = x1 + x2
         
         comp = (t_fine * 5 + 128) >> 8
         
         return comp
         */
    }
    
    
    private func compensatePressureMeasurement(_ uncomp: Int32) -> UInt32{
        if t_fine != 0{
            /* 32-BIT COMPENSATION FORMULA returns UInt32 */
            
            var x1 : Int32 = 0
            var x2 : Int32 = 0
            var comp : UInt32 = 0
            x1 = ((Int32(t_fine))>>1) - (Int32(64000))
            x2 = (((x1 >> 2) * (x1 >> 2)) >> 11 ) * (Int32(P6))
            
            x2 = x2 + ((x1 * (Int32(P5)))<<1)
            x2 = (x2 >> 2) + ((Int32(P4))<<16)
            x1 = (((Int32(P3)*(((x1>>2) * (x1>>2))>>13))>>3) + (((Int32(P2))*x1)>>1))>>18
            x1 = ((((32768 + x1)) * (Int32(P1)))>>15)
            
            if(x1 == 0)  {
                return 0
            }
            comp = ((UInt32(((Int32(1048576)) - uncomp) - (x2 >> 12)))) * 3125
            if ( comp < 0x80000000){
                comp = (comp<<1)/(UInt32(x1))
            } else{
                comp = (comp/UInt32(x1)) * 2
            }
            
            x1 = ((Int32(P9)) * (Int32((((comp>>3) * (comp>>3))>>13))))>>12
            x2 = ((Int32((comp>>2))) * (Int32(P8)))>>13
            comp = UInt32(Int32(comp) + ((x1 + x2 + Int32(P7)) >> 4))
            
            return comp
            
            /*   DOUBLE COMPENSATION FORMULA  returns Double */
            /*
             var x1: Double = 0
             var x2: Double = 0
             var comp: Double = 0
             
             x1 = (Double(t_fine)/2.0) - 64000.0
             x2 = x1 * x1 * (Double(P6)) / 32768.0
             x2 = x2 * x1 * (Double(P5)) * 2.0
             x2 = (x2/4.0) + ((Double(P4)) * 65536.0)
             x1 = ((Double(P3)) * x1 * x1 / 524288.0 + (Double(P2)) * x1) / 524288.0
             x1 = (1.0 + x1 / 32768.0) * (Double(P1))
             if(x1 == 0.0){
             return 0.0
             }
             
             comp = 1048576.0 - Double(uncomp)
             comp = (comp - (x2 / 4096.0)) * 6250.0 / x1
             x1 = (Double(P9)) * comp * comp / 2147483648.0
             x2 = comp * (Double(P8)) / 32768.0
             comp = comp + (x1 + x2 + (Double(P7))) / 16.0
             return comp
             
             */
            
            
            
            /*   64-BIT COMPENSATION FORMULA returns UInt32 */
            /*
             var x1: Int64 = 0
             var x2: Int64 = 0
             var comp: Int64 = 0
             
             x1 = (Int64(t_fine)) - 128000   //1
             x2 = x1 * x1 * Int64(P6) //2
             x2 = x2 + ((x1 * Int64(P5)) << 17)  //3
             x2 = x2 + (Int64(P4) << 35)    //4
             x1 = ((x1 * x1 * Int64(P3))>>8) + ((x1 * Int64(P2)) << 12) //5
             x1 = (((Int64(1) << 47) + x1) * Int64(P1)) >> 33
             if (x1 == 0){
             return 0
             } //7
             comp = Int64(1048576) - Int64(uncomp) //8
             comp = (((comp << 31) - x2) * 3125) / x1 //9
             
             x1 = (Int64(P9) * (comp >> 13) * (comp >> 13)) >> 25 //10
             x2 = (Int64(P8) * comp) >> 19 //11
             comp = ((comp + x1 + x2) >> 8) + ((Int64(P7)) << 4) //12
             
             return UInt32(comp)
             
             
             */
            
            
        }else{
            print("T_fine has not been calculated. Make sure that a temperature measurement is made before calculating pressure")
            return 0
        }
    }
}
