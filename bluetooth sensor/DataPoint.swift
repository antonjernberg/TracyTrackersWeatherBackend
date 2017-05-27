//
//  DataPoint.swift
//  bluetooth sensor
//
//  Created by Anton Jernberg on 2017-05-12.
//  Copyright © 2017 TracyTrackers. All rights reserved.
//

import Foundation

/**
 * A class for storing pressure data.
 **/
class DataPoint: NSObject, NSCoding{
    var pressure: Double!
    var time: Date!
    
    
    /**
    * @param pressure : a Decimal representation of the pressure
    * @param time : a Date representing the time the data was stored
    */
    required init(pressure press: Double, time stamp: Date){
        self.pressure = press
        self.time = stamp
    }
    
    required init(coder aDecoder: NSCoder) {
        self.pressure = aDecoder.decodeObject(forKey: "pressure") as! Double
        self.time = aDecoder.decodeObject(forKey: "time") as! Date
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(pressure, forKey: "pressure")
        aCoder.encode(time, forKey: "time")
    }
}
