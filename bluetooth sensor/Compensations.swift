//
//  Compensations.swift
//  bluetooth sensor
//
//  Created by anton on 2017-05-24.
//  Copyright © 2017 Anton. All rights reserved.
//

import Foundation


struct Compensations{
    private var t_fine: Int32 = 0
    
    // Variables for storing Calibration Parameters from the BME280 sensor
    private var T1: UInt16?
    private var T2: Int16?
    private var T3: Int16?
    private var P1: UInt16?
    private var P2: Int16?
    private var P3: Int16?
    private var P4: Int16?
    private var P5: Int16?
    private var P6: Int16?
    private var P7: Int16?
    private var P8: Int16?
    private var P9: Int16?
    private var initialized = false
    init(){
        
    }
    /**
     * Sets all pressure parameters.
     *   @param _: An array containing calibration parameters for Pressure received directly from the Sensor
     */
    mutating func setPressureParameters(_ param: [Any]) -> Void {
        P1 = UInt16((UInt16((param[1] as! UInt8)) << 8) | UInt16(param[0] as! UInt8))
        P2 = Int16((Int16((param[3] as! Int8)) << 8) | Int16(param[2] as! Int8))
        P3 = Int16((Int16((param[5] as! Int8)) << 8) | Int16(param[4] as! Int8))
        P4 = Int16((Int16((param[7] as! Int8)) << 8) | Int16(param[6] as! Int8))
        P5 = Int16((Int16((param[9] as! Int8)) << 8) | Int16(param[8] as! Int8))
        P6 = Int16((Int16((param[11] as! Int8)) << 8) | Int16(param[10] as! Int8))
        P7 = Int16((Int16((param[13] as! Int8)) << 8) | Int16(param[12] as! Int8))
        P8 = Int16((Int16((param[15] as! Int8)) << 8) | Int16(param[14] as! Int8))
        P9 = Int16((Int16((param[17] as! Int8)) << 8) | Int16(param[17] as! Int8))
        if(T1 != nil && T2 != nil && T3 != nil){
            initialized = true
        }
    }
    
    /**
     * Sets all pressure parameters.
     *   @param _: An array containing calibration parameters for Pressure received directly from the Sensor
     */
    mutating func setTemperatureParameters(_ param: [Any]) -> Void {
        T1 = UInt16((UInt16((param[1] as! UInt8)) << 8) | UInt16(param[0] as! UInt8))
        T2 = Int16((Int16((param[3] as! Int8)) << 8) | Int16(param[2] as! Int8))
        T3 = Int16((Int16((param[5] as! Int8)) << 8) | Int16(param[4] as! Int8))
        
        if(P1 != nil && P2 != nil && P3 != nil && P4 != nil && P5 != nil && P6 != nil && P7 != nil && P8 != nil && P9 != nil){
            initialized = true
        }
    }
    
    
    /**
     *   Compensates the temperature value received from the BME280 sensor using calibration parameters received from the sensor.
     *
     *   @param uncomp : the uncompensated temperature value read directly from the sensor
     *   @return : the compensated value of the temperature as signed Int16.
     **/
    mutating func compensateTemperatureMeasurement(_ uncomp: Int32) -> Double                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             {
        if(initialized){
            /*  DOUBLE COMPENSATION FORMULA returns Double*/
            
            var x1 : Double = 0
            var x2 : Double = 0
            var comp : Double = 0
            
            x1 = ((Double(uncomp))/16384.0 - (Double(T1!))/1024.0) * (Double(T2!))
            x2 = (((Double(uncomp))/131072.0 - (Double(T1!))/8192.0) * ((Double(uncomp))/131072.0 - (Double(T1!))/8192.0)) * (Double(T3!))
            t_fine = Int32(x1 + x2)
            comp = (x1 + x2) / 5120.0
            return comp
            
            
            
            
            /* 32 - BIT COMPENSATION FORMULA returns Int32*/
            /*
             var comp: Int32 = 0
             var x1: Int32 = 0
             var x2: Int32 = 0
             
             // calculate x1
             x1 = ((((uncomp >> 3) - (Int32(T1!)<<1))) * (Int32(T2!))) >> 11
             
             // calculate x2
             x2 = (((((uncomp >> 4) - (Int32(T1!))) * ((uncomp>>4) - (Int32(T1!)))) >> 12) * (Int32(T3!))) >> 14
             
             t_fine = x1 + x2
             
             comp = (t_fine * 5 + 128) >> 8
             
             return comp
             */
        }
        else{
            print("Please set calibration parameters first")
            return 0.0
        }
    }
    
    
    
    /**
     *   Compensates the pressure value received from the BME280 sensor using calibration parameters received from the sensor.
     *
     *   @param uncomp : the uncompensated temperature value read directly from the sensor
     *   @return : the compensated value of the temperature as signed Int16.
     **/
    func compensatePressureMeasurement(_ uncomp: Int32) -> UInt32{
        if(initialized){
            if t_fine != 0{
                /* 32-BIT COMPENSATION FORMULA returns UInt32 */
                
                var x1 : Int32 = 0
                var x2 : Int32 = 0
                var comp : UInt32 = 0
                x1 = ((Int32(t_fine))>>1) - (Int32(64000))
                x2 = (((x1 >> 2) * (x1 >> 2)) >> 11 ) * (Int32(P6!))
                
                x2 = x2 + ((x1 * (Int32(P5!)))<<1)
                x2 = (x2 >> 2) + ((Int32(P4!))<<16)
                x1 = (((Int32(P3!)*(((x1>>2) * (x1>>2))>>13))>>3) + (((Int32(P2!))*x1)>>1))>>18
                x1 = ((((32768 + x1)) * (Int32(P1!)))>>15)
                
                if(x1 == 0)  {
                    return 0
                }
                comp = ((UInt32(((Int32(1048576)) - uncomp) - (x2 >> 12)))) * 3125
                if ( comp < 0x80000000){
                    comp = (comp<<1)/(UInt32(x1))
                } else{
                    comp = (comp/UInt32(x1)) * 2
                }
                
                x1 = ((Int32(P9!)) * (Int32((((comp>>3) * (comp>>3))>>13))))>>12
                x2 = ((Int32((comp>>2))) * (Int32(P8!)))>>13
                comp = UInt32(Int32(comp) + ((x1 + x2 + Int32(P7!)) >> 4))
                
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
        
        }else{
            print("Please set calibration parameters first")
            return 0
        }
    }
}

