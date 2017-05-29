//
//  AppDelegate.swift
//  MotoIntercom
//
//  Created by Logan Kember on 2016-07-05.
//  Copyright © 2016 Logan Kember. All rights reserved.
//

import UIKit
import MultipeerConnectivity

@available(iOS 10.0, *)
@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var connectionManager : ConnectionManager!
    var uniqueID: String!
    var peer : MCPeerID!
    
    var messages = [MessageObject]()
    
    var didAcceptCall = false

    // Used for haptic feedback
    var generator = UIImpactFeedbackGenerator(style: UIImpactFeedbackStyle.light)
    
    // Used for saving and loading peerID and uniqueID
    let uniqueIDString = "uniqueIDString"
    let peerIDString = "selfMCPeerID"
    
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        generator.prepare() //Preparing haptic feedback engine
        
        let didLoad = loadIdentification()
        
        if (!didLoad) {
            connectionManager = ConnectionManager()
            saveIdentification(peer: connectionManager.peer, uniqueID: connectionManager.uniqueID)
        }
        else {
            connectionManager = ConnectionManager(peerID: peer, uniqueID: uniqueID)
        }
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
        
        print("\(#file) > \(#function) > resigned active")
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        
        connectionManager.advertiser.startAdvertisingPeer()
        connectionManager.browser.stopBrowsingForPeers()
        
        print("\(#file) > \(#function) > Entered background")
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
        
        connectionManager.advertiser.startAdvertisingPeer()
        connectionManager.browser.startBrowsingForPeers()
        
        print("\(#file) > \(#function) > Entered foreground")
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        print("\(#file) > \(#function) > Became active")
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        print("\(#file) > \(#function) > disconnecting from session.")
        
        for session in connectionManager.sessions {
            session.disconnect()
        }
        
        connectionManager.browser.stopBrowsingForPeers()
        connectionManager.advertiser.stopAdvertisingPeer()
    }

    
    // MARK: Saving
    
    func saveIdentification(peer : MCPeerID, uniqueID: String) {
        print("\(#file) > \(#function) > peerID: \(peer.displayName) and uniqueID: \(uniqueID) are being saved")
        
        let peerIDData = NSKeyedArchiver.archivedData(withRootObject: peer)
        let uniqueIDData = NSKeyedArchiver.archivedData(withRootObject: uniqueID)
        
        let defaults = UserDefaults.standard
        defaults.set(peerIDData, forKey: peerIDString)
        defaults.set(uniqueIDData, forKey: uniqueIDString)
    }
    
    func loadIdentification() -> Bool {
        print("\(#file) > \(#function) > Entry")
        
        var didLoadPeerID = false
        var didLoadUniqueID = false
        
        let defaults = UserDefaults.standard
        
        if let peerData = defaults.object(forKey: peerIDString) as? Data {
            if let peerID = NSKeyedUnarchiver.unarchiveObject(with: peerData) as? MCPeerID {
                self.peer = peerID
                print("\(#file) > \(#function) > Successful load of peerID - \(peerID)")
                didLoadPeerID = true
            }
        }
        
        if let uniqueData = defaults.object(forKey: uniqueIDString) as? Data {
            if let uniqueID = NSKeyedUnarchiver.unarchiveObject(with: uniqueData) as? String {
                self.uniqueID = uniqueID
                print("\(#file) > \(#function) > Successful load of uniqueID")
                didLoadUniqueID = true
            }
        }
        
        if (didLoadPeerID && didLoadUniqueID) {
            return true
        }
        else {
            print("\(#file) > \(#function) > false: didLoadPeerID=\(didLoadPeerID), didLoadUniqueID=\(didLoadUniqueID)")
            return false
        }
        
    }
    
}

