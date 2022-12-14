//
//  String+C.swift
//  OpenTerm
//
//  Created by Louis D'hauwe on 08/04/2018.
//  Copyright © 2018 Silver Fox. All rights reserved.
//

import Foundation
import UIKit

extension String {
	
	func toCString() -> UnsafePointer<Int8>? {
		let nsSelf: NSString = self as NSString
		return nsSelf.cString(using: String.Encoding.utf8.rawValue)
	}

	var utf8CString: UnsafeMutablePointer<Int8> {
		return UnsafeMutablePointer(mutating: (self as NSString).utf8String!)
	}
    
    /// Generates a `UIImage` instance from this string using a specified
    /// attributes and size.
    ///
    /// - Parameters:
    ///     - attributes: to draw this string with. Default is `nil`.
    ///     - size: of the image to return.
    /// - Returns: a `UIImage` instance from this string using a specified
    /// attributes and size, or `nil` if the operation fails.
    /// https://stackoverflow.com/questions/51100121/how-to-generate-an-uiimage-from-custom-text-in-swift
    func image(withAttributes attributes: [NSAttributedString.Key: Any]? = nil, size: CGSize? = nil) -> UIImage? {
        let textSize = (self as NSString).size(withAttributes: attributes)
        var size = size ?? textSize
        if (textSize.width > size.width) {
            size.width = textSize.width
        }
        let origin = CGPoint(x:size.width/2 - textSize.width/2, y: size.height/2 - textSize.height/2)
        return UIGraphicsImageRenderer(size: size).image { (context) in
            (self as NSString).draw(in: CGRect(origin: origin, size: size),
                                    withAttributes: attributes)
        }
    }
    	
}

func convertCArguments(argc: Int32, argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> [String]? {
	
	var args = [String]()
	
	for i in 0..<Int(argc) {
		
		guard let argC = argv?[i] else {
			return nil
		}
		
		let arg = String(cString: argC)
		
		args.append(arg)
		
	}
	
	return args
}
