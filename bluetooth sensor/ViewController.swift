//
//  ViewController.swift
//  bluetooth sensor
//
//  Created by Anton on 2017-05-10.
//  Copyright © 2017 Anton. All rights reserved.
//

import UIKit
import Foundation


class ViewController: UIViewController	{
    
    var automat: AutomatCommunication = AutomatCommunication()
    
    
    
    
    
    //var connectionManager : NLAConnectionManager = NLAConnectionManager.sharedConnectionManager()
    @IBOutlet weak var PressureDisplay: UILabel!

    @IBOutlet weak var TempDisplay: UILabel!


    
    // Create a dispatchQueue for the CentralManager. This executes tasks in serial
    let serialQueue = DispatchQueue(label: "queue")
    
    @IBOutlet weak var NoteDisplay: UILabel! = UILabel()
    
    
    @IBOutlet weak var StateDisplay: UILabel! = UILabel()
    
    @IBOutlet weak var AutomatDisplay: UILabel! = UILabel()


    
    
   
    func connectionInfoUpdate(notification note: Notification){
        StateDisplay.text = String(describing: note.object!)
    }
 
    func dataUpdate(notification note: Notification){
        PressureDisplay.text = "Pressure: \(String(describing:note.object!))"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(forName: Notification.Name(rawValue: "automatConnectionInfo"), object: nil, queue: OperationQueue.main, using: connectionInfoUpdate(notification:))
        
        NotificationCenter.default.addObserver(forName: Notification.Name(rawValue: "automatNewValue"), object: nil, queue: OperationQueue.main, using: dataUpdate(notification:))
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

