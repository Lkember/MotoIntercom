//
//  StartupViewController.swift
//  MotoIntercom
//
//  Created by Logan Kember on 2016-07-25.
//  Copyright © 2016 Logan Kember. All rights reserved.
//

import UIKit

class StartupViewController: UIViewController {
    
    // MARK: Properties
    
    
    // MARK: Actions
    @IBAction func startSearching(sender: UIButton) {
        performSegueWithIdentifier("chatSegue", sender: self)
    }
    
    
    override func viewDidLoad() {
        
    }
}
