//
//  FirstViewController.swift
//  MotoIntercom
//
//  Created by Logan Kember on 2016-07-05.
//  Copyright © 2016 Logan Kember. All rights reserved.
//

import UIKit

class FirstViewController: UIViewController {
    
    // MARK: Properties
    @IBOutlet weak var randLabel: UILabel!
    @IBOutlet weak var textField: UITextField!
    
    
    // MARK: Actions
    @IBAction func setRandomLabel(sender: UIButton) {
        if (textField.text != "") {
            randLabel.text = textField.text;
        }
        else {
            randLabel.text = "Nice try"
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

}

