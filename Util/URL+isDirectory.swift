//
//  URL+isDirectory.swift
//  Carnets
//
//  Created by Anders Borum on 22/06/2017.
//  Copyright © 2017 Applied Phasor. All rights reserved.
//

import Foundation

extension URL {
    // shorthand to check if URL is directory
    public var isDirectory: Bool {
        let keys = Set<URLResourceKey>([URLResourceKey.isDirectoryKey])
        let value = try? self.resourceValues(forKeys: keys)
        switch value?.isDirectory {
        case .some(true):
            return true
            
        default:
            return false
        }
    }
    
    public var isSymbolicLink: Bool {
        let keys = Set<URLResourceKey>([URLResourceKey.isSymbolicLinkKey])
        let value = try? self.resourceValues(forKeys: keys)
        switch value?.isSymbolicLink {
        case .some(true):
            return true
            
        default:
            return false
        }
    }
    
    public var contentModificationDate: Date {
        let keys = Set<URLResourceKey>([URLResourceKey.contentModificationDateKey])
        let value = try? self.resourceValues(forKeys: keys)
        return value?.contentModificationDate ?? Date(timeIntervalSince1970: 0)
    }
    
    // compare 2 URLs and return true if they correspond to the same
    // file path, taking into account the possibility that iOS sometimes
    // adds "/private" in front of file URLs.
    func sameFileLocation(path: String?) -> Bool {
        if (path == nil) { return false }
        if (!self.isFileURL) { return false }
        // same path? OK
        if (self.path == path) { return true }
        // Maybe one begins with /var, the other with /private/var:
        if (self.path.hasPrefix("/private/") && path!.hasPrefix("/var/")) {
            var shorterPath = self.path
            shorterPath.removeFirst("/private".count)
            if (shorterPath == path) { return true }
        } else if (self.path.hasPrefix("/var/") && path!.hasPrefix("/private/")) {
            var shorterPath = path!
            shorterPath.removeFirst("/private".count)
            if (self.path == shorterPath) { return true }
        }
        return false
    }
}

