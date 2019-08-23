//
//  AppDelegate.swift
//  a-Shell
//
//  Created by Nicolas Holzschuch on 30/06/2019.
//  Copyright © 2019 AsheKube. All rights reserved.
//

import UIKit
import ios_system

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {



    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        initializeEnvironment()
        setenv("LC_CTYPE", "UTF-8", 1);
        setenv("LC_ALL", "UTF-8", 1);
        setenv("VIMRUNTIME", Bundle.main.resourcePath! + "/vim", 1); // main resource for vim files
        let documentsUrl = try! FileManager().url(for: .documentDirectory,
                                                  in: .userDomainMask,
                                                  appropriateFor: nil,
                                                  create: true)
        setenv("VIMHOME", documentsUrl.path, 1); // user vim files

        setlocale(LC_CTYPE, "UTF-8");
        setlocale(LC_ALL, "UTF-8");
        // iCloud abilities:
        // We check whether the user has iCloud ability here, and that the container exists
        let currentiCloudToken = FileManager().ubiquityIdentityToken
        // print("Available fonts: \(UIFont.familyNames)");
        let homeUrl = documentsUrl.deletingLastPathComponent()
        FileManager().changeCurrentDirectoryPath(documentsUrl.path)
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        NSLog("application configurationForConnecting connectingSceneSession \(connectingSceneSession)")
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
        NSLog("application didDiscardSceneSessions sceneSessions \(sceneSessions)")
    }


}

