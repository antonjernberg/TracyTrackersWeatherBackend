//
//  DataPoint.swift
//  bluetooth sensor
//
//  Created by Anton on 2017-05-12.
//  Copyright © 2017 Anton. All rights reserved.
//

import Foundation


struct DataPoint{
    var temperature: Decimal?
    var time: Date?
    
    init(temperature temp: Decimal, time stamp: Date){
        temperature = temp
        time = stamp
    }

}
