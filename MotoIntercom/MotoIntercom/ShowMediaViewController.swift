//
//  ShowMediaViewController.swift
//  MotoIntercom
//
//  Created by Logan Kember on 2017-04-16.
//  Copyright © 2017 Logan Kember. All rights reserved.
//

import UIKit

class ShowMediaViewController: UIViewController, UIScrollViewDelegate {

    var image: UIImage? = nil
    
    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet weak var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if (image == nil) {
            print("\(type(of: self)) > \(#function) > Could not find image...")
        }
        else {
            imageView.image = image
        }
        
        UIApplication.shared.isStatusBarHidden = true
        
        self.scrollView.minimumZoomScale = 1
        self.scrollView.maximumZoomScale = 6.0
        self.scrollView.contentSize = self.imageView.frame.size
        self.scrollView.delegate = self
        
        let tapGesture = UITapGestureRecognizer.init(target: self, action: #selector(self.toggleNavBar))
        self.scrollView.addGestureRecognizer(tapGesture)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        self.navigationController?.hidesBarsOnTap = false
        self.navigationController?.setNavigationBarHidden(true, animated: true)
    }
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.imageView
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override var prefersStatusBarHidden: Bool {
        if (navigationController!.isNavigationBarHidden) {
            return true
        }
        else {
            return false
        }
    }
    
    @objc func toggleNavBar() {
        if (self.navigationController!.navigationBar.isHidden) {
            self.navigationController?.setNavigationBarHidden(false, animated: true)
            self.setNeedsStatusBarAppearanceUpdate()
        }
        else {
            self.navigationController?.setNavigationBarHidden(true, animated: true)
            self.setNeedsStatusBarAppearanceUpdate()
        }
    }
    
    // MARK: - UIScrollViewDelegate
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
