//
//  AppDelegate.swift
//  MotoIntercom
//
//  Created by Logan Kember on 2016-07-05.
//  Copyright © 2016 Logan Kember. All rights reserved.
//

import UIKit
import MultipeerConnectivity

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var connectionManager : ConnectionManager!
    var peer : MCPeerID!
    var peerIDString = "selfMCPeerID"

    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        if (!canLoadMCPeerID()) {
            connectionManager = ConnectionManager()
            
            saveMCPeerID(peer: connectionManager.peer)
        }
        else {
            connectionManager = ConnectionManager(peerID: peer)
        }
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        print("AppDelegate > applicationWillTerminate > disconnecting from session.")
        connectionManager.session.disconnect()
        connectionManager.browser.stopBrowsingForPeers()
        connectionManager.advertiser.stopAdvertisingPeer()
    }

    
    // MARK: Saving
    
    func saveMCPeerID(peer : MCPeerID) {
        print("AppDelegate > saveMCPeerID > peerID \(peer.displayName) is being saved permanently.")
        
        let data = NSKeyedArchiver.archivedData(withRootObject: peer)
        
        let defaults = UserDefaults.standard
        defaults.set(data, forKey: peerIDString)
    }
    
    func canLoadMCPeerID() -> Bool {
        let defaults = UserDefaults.standard
        
        if let data = defaults.object(forKey: peerIDString) as? Data {
            if let peerID = NSKeyedUnarchiver.unarchiveObject(with: data) as? MCPeerID {
                self.peer = peerID
                print("AppDelegate > canLoadMCPeerID > true")
                return true
            }
            print("AppDelegate > canLoadMCPeerID > false, could not unarchive data")
            return false
        }
        print("AppDelegate > canLoadMCPeerID > false, defaults object could not be found")
        return false
    }
    
}

