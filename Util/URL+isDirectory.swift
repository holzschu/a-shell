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
    
    public var contentModificationDate: Date {
        let keys = Set<URLResourceKey>([URLResourceKey.contentModificationDateKey])
        var value = try? self.resourceValues(forKeys: keys)
        return value?.contentModificationDate ?? Date(timeIntervalSince1970: 0)
    }
    
    // compare 2 URLs and return true if they correspond to the same
    // page, excluding parameters and queries. This avoids infinite
    // loops with redirections.
    // Maybe we need to include parameters, but queries are excluded.
    // We had an infinite loop with http://localhost:8888/nbextensions/
    // loading http://localhost:8888/nbextensions/?nbextension=zenmode/main
    func sameLocation(url: URL?) -> Bool {
        if (url == nil) { return false }
        if (self.host != url!.host) { return false }
        if (self.port != url!.port) { return false }
        if (self.path != url!.path) { return false }
        return true
    }
    

    
    
}

