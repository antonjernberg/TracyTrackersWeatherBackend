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
    private var timer: Timer?
    private var timerForCountingAverage: Timer?
    private var arrayForCountingAverage: [Double]?
    private var compensations: Compensations = Compensations()
    
    // An object representing a connection manager used to connect with the Automat board
    private let automatConnectionManager = NLAConnectionManager()
    
    // An object representing the Automat baseboard. Provides access to the functionality of the Automat board
    private var automatBaseboard: NLABaseBoard?
    private var automatDevice : NLAAutomatDevice?
    private var averageChangeOfPressurePerHour : Double? = 0.0
    
    // A local array for storing DataPoints
    private var pressureStorage: [DataPoint]!
    
    // Pointers to UInt8 arrays containing commands for writing to the registers of a BME280 sensor
    private let pointerToStartSensorCommand = UnsafeMutablePointer<UInt8>.allocate(capacity: 2)
    private let pointerToStartFilterCommand = UnsafeMutablePointer<UInt8>.allocate(capacity: 2)
    private let pointerToStartResetCommand = UnsafeMutablePointer<UInt8>.allocate(capacity: 2)
    
    
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
                print("Wrote to register")
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
                self.compensations.setTemperatureParameters(responseData!.responses)
            }
        }
        
        
        // The handler used to store the fetched calibration parameters for PRESSURE (P1 - P9)
        let pressureCalibrationParameterHandler: NLAI2CReadHandler = {(_ responseData: NLAI2CReadResponseData?, _ error: Error?) -> Void in
            if error != nil{
                print("error")
            }else{
                self.compensations.setPressureParameters(responseData!.responses)
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
    
    
    /**
    * Start a new Measurement by setting a Timer object to repeat readings for 1 Minute.
    */
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
                    print("Temperature: \(self.compensations.compensateTemperatureMeasurement(temperature))")
                    
                    
                    let newPressure = self.compensations.compensatePressureMeasurement(pressure)
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
    }

