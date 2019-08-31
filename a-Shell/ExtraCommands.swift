//
//  extraCommands.swift
//  a-Shell: file for extra commands added to a-Shell.
//  Part of the difficulty is identifying which window scene is active. See history() for an example. 
//
//  Created by Nicolas Holzschuch on 30/08/2019.
//  Copyright © 2019 AsheKube. All rights reserved.
//

import Foundation
import UIKit
import ios_system


@_cdecl("history")
public func history(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    var rootVC:UIViewController? = nil
    let opaquePointer = OpaquePointer(ios_getContext())
    guard let stringPointer = UnsafeMutablePointer<CChar>(opaquePointer) else { return 0 }
    let currentSessionIdentifier = String(cString: stringPointer)
    for scene in UIApplication.shared.connectedScenes {
        NSLog("identifier: \(scene.session.persistentIdentifier) context = \(currentSessionIdentifier)")
        if (scene.session.persistentIdentifier == currentSessionIdentifier) {
            let delegate: SceneDelegate = scene.delegate as! SceneDelegate
            delegate.printHistory()
            return 0
        }
    }
    return 0
}

@_cdecl("tex")
public func tex(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32 {
    let command = argv![0]
    fputs(command, thread_stderr)
    fputs(" requires the TeX distribution, which is not currently installed. Do you want to download and install it? (1.8 GB) (y/N)", thread_stderr)
    fflush(thread_stderr)
    var byte: Int8 = 0
    let count = read(fileno(thread_stdin), &byte, 1)
    if (byte == 121) || (byte == 89) {
        var appdelegate : AppDelegate = UIApplication.shared.delegate as! AppDelegate
        fputs("Downloading the TeX distribution, this may take some time...", thread_stderr)
        fputs("\n(you can always remove it later using Settings)\n", thread_stderr)
        appdelegate.downloadTeX()
        return 0
    }
    return 0
}

