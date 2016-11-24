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
    @IBAction func startSearching(_ sender: UIButton) {
        print("Changing to ChatView")
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        navigationItem.backBarButtonItem?.title = "Stop Search"
    }
    
    override func viewDidLoad() {
        
    }
}
