//
//  ExtensionPoint.swift
//  UIExtensionExample
//
//  Created by Khaos Tian on 6/9/25.
//

import Foundation
import ExtensionFoundation

@available(iOS 26.0, *)
extension AppExtensionPoint {
    @Definition
    public static var localWebServerExtension: AppExtensionPoint {
        Name("localWebServer")
        UserInterface(false)
    }
}
