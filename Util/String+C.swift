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
    
    // takes as input a String that contains litteral UTF8 characters (like "\u{0009}")
    // and converts these to the actual UTF8 character (\u{0009}, or tabulation in that case)
    var convertUnicode: String {
        // converting "\u{00xx}" (litteral) into the actual character \u{00xx}:
        // a) match \u{00xx} using regex
        // Regex: we need four slashes to match with "\u", two for the curly brackets:
        do {
            var newTitle = ""
            var offset = 0
            let regex = try NSRegularExpression(pattern: "\\\\u\\{([0-9a-fA-F]+)\\}", options: [])
            let matches = regex.matches(in: self, range: NSRange(self.startIndex..<self.endIndex, in: self))
            for match in matches {
                let range = match.range
                newTitle += self[self.index(self.startIndex, offsetBy:offset)..<self.index(self.startIndex, offsetBy: range.lowerBound)]
                var subString = self[self.index(self.startIndex, offsetBy:range.lowerBound)..<self.index(self.startIndex, offsetBy: range.upperBound)]
                subString.removeFirst(3)
                subString.removeLast()
                if let unicodeScalar = UInt8(subString, radix: 16) {
                    newTitle += String(Character(UnicodeScalar(unicodeScalar)))
                } else {
                    // conversion failure, store the unmodified string:
                    newTitle += self[self.index(self.startIndex, offsetBy:range.lowerBound)..<self.index(self.startIndex, offsetBy: range.upperBound)]
                }
                offset = range.upperBound
                // NSLog("Edited prompt: \(newPrompt) offset: \(offset)")
            }
            newTitle += self[self.index(self.startIndex, offsetBy:offset)..<self.index(self.endIndex, offsetBy: 0)]
            return newTitle
        }
        catch {
            NSLog("Error converting \(self): \(error)")
        }
        return self
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

// TODO: kept to remember that I tried it and it doesn't work. Must be removed.
// It does convert <br> but not \u{0009}
extension String {
    var attributedHtmlString: NSAttributedString? {
        try? NSAttributedString(
            data: Data(utf8),
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
        )
    }
}
