//
//  UIColor+hexString.swift
//  a-Shell
//
//  From https://www.iosapptemplates.com/blog/swift-programming/convert-hex-colors-to-uicolor-swift-4.
//  
//

import Foundation
import UIKit
import SwiftTerm

extension UIColor {
    convenience init(hexString: String, alpha: CGFloat = 1.0) {
        let hexString: String = hexString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let scanner = Scanner(string: hexString)
        if (hexString.hasPrefix("#")) {
            scanner.scanLocation = 1
        }
        var color: UInt32 = 0
        scanner.scanHexInt32(&color)
        let mask = 0x000000FF
        let r = Int(color >> 16) & mask
        let g = Int(color >> 8) & mask
        let b = Int(color) & mask
        let red   = CGFloat(r) / 255.0
        let green = CGFloat(g) / 255.0
        let blue  = CGFloat(b) / 255.0
        self.init(red:red, green:green, blue:blue, alpha:alpha)
    }
    func toHexString() -> String {
        var r:CGFloat = 0
        var g:CGFloat = 0
        var b:CGFloat = 0
        var a:CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        let rgb:Int = (Int)(r*255)<<16 | (Int)(g*255)<<8 | (Int)(b*255)<<0
        return String(format:"#%06x", rgb)
    }
    
    func toSwiftTermColor() -> SwiftTerm.Color {
        var r:CGFloat = 0
        var g:CGFloat = 0
        var b:CGFloat = 0
        var a:CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return SwiftTerm.Color(red: UInt16(r * 65535), green: UInt16(g * 65535), blue: UInt16(b * 65535))
    }
    
    // Swift
    func inverseColor() -> UIColor {
        var alpha: CGFloat = 1.0
        
        var white: CGFloat = 0.0
        if self.getWhite(&white, alpha: &alpha) {
            return UIColor(white: 1.0 - white, alpha: alpha)
        }
        
        var hue: CGFloat = 0.0, saturation: CGFloat = 0.0, brightness: CGFloat = 0.0
        if self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            return UIColor(hue: 1.0 - hue, saturation: 1.0 - saturation, brightness: 1.0 - brightness, alpha: alpha)
        }
        
        var red: CGFloat = 0.0, green: CGFloat = 0.0, blue: CGFloat = 0.0
        if self.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return UIColor(red: 1.0 - red, green: 1.0 - green, blue: 1.0 - blue, alpha: alpha)
        }
        
        return self
    }
    
    func getBrightness() -> CGFloat {
        var alpha: CGFloat = 1.0
        var hue: CGFloat = 0.0, saturation: CGFloat = 0.0, brightness: CGFloat = 0.0
        if self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            return brightness
        }
        return 0
    }
    
    func makeTransparent() -> UIColor {
        var alpha: CGFloat = 1.0
        var newAlpha: CGFloat = 0.5
        
        var red: CGFloat = 0.0, green: CGFloat = 0.0, blue: CGFloat = 0.0
        if self.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return UIColor(red: red, green: green, blue: blue, alpha: newAlpha)
        }
        
        var hue: CGFloat = 0.0, saturation: CGFloat = 0.0, brightness: CGFloat = 0.0
        if self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            return UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: newAlpha)
        }
        
        var white: CGFloat = 0.0
        if self.getWhite(&white, alpha: &alpha) {
            return UIColor(white: white, alpha: newAlpha)
        }
        
        return self

    }
    
    func nonTransparent() -> UIColor {
        var alpha: CGFloat = 1.0
        
        var red: CGFloat = 0.0, green: CGFloat = 0.0, blue: CGFloat = 0.0
        if self.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return UIColor(red: red, green: green, blue: blue, alpha: 1.0)
        }
        
        var hue: CGFloat = 0.0, saturation: CGFloat = 0.0, brightness: CGFloat = 0.0
        if self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            return UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1.0)
        }
        
        var white: CGFloat = 0.0
        if self.getWhite(&white, alpha: &alpha) {
            return UIColor(white: white, alpha: 1.0)
        }
        
        return self
    }

    func image(_ size: CGSize = CGSize(width: 1, height: 1)) -> UIImage {
        return UIGraphicsImageRenderer(size: size).image { rendererContext in
            self.setFill()
            rendererContext.fill(CGRect(origin: .zero, size: size))
        }
    }
}



func colorFromName(name: String) -> UIColor? {
    // First, try with names:
    switch (name) {
    case "systemBlue":
        return .systemBlue
    case "systemGreen":
        return .systemGreen
    case "systemIndigo":
        return .systemIndigo
    case "systemOrange":
        return .systemOrange
    case "systemPink":
        return .systemPink
    case "systemPurple":
        return .systemPurple
    case "systemRed":
        return .systemRed
    case "systemTeal":
        return .systemTeal
    case "systemYellow":
        return .systemYellow
    case "systemGray":
        return .systemGray
    case "systemGray2":
        return .systemGray2
    case "systemGray3":
        return .systemGray3
    case "systemGray4":
        return .systemGray4
    case "systemGray5":
        return .systemGray5
    case "systemGray6":
        return .systemGray6
    case "black":
        return .black
    case "blue":
        return .blue
    case "brown":
        return .brown
    case "cyan":
        return .cyan
    case "darkGray":
        return .darkGray
    case "gray":
        return .gray
    case "green":
        return .green
    case "lightGray":
        return .lightGray
    case "magenta":
        return .magenta
    case "orange":
        return .orange
    case "purple":
        return .purple
    case "red":
        return .red
    case "white":
        return .white
    case "yellow":
        return .yellow
    default:
        if let color = UIColor(named: name) {
            return color
        }
    }
    // If we've made it so far, it is not one of the named color. Is it a valid hexstring?
    if (name.count == 6) || (name.count == 7 && name.hasPrefix("#")) {
        var string = name
        if (string.hasPrefix("#")) {
            string.removeFirst(1)
        }
        let allowedCharacterSet = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")
        let characterSet = CharacterSet(charactersIn: string)
        if allowedCharacterSet.isSuperset(of: characterSet) {
            return UIColor(hexString: name)
        }
    }
    return nil
}

