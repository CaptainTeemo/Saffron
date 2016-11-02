//
//  CacheRecorder.swift
//  Saffron
//
//  Created by CaptainTeemo on 11/2/16.
//  Copyright © 2016 Captain Teemo. All rights reserved.
//

import Foundation

public protocol CacheRecorder {
    associatedtype T
    
    func unarchive(with path: String) -> T?
    func archive(with path: String, value: T) -> Bool
}

extension CacheRecorder where Self.T: Any {
    typealias V = T
    
    public func unarchive(with path: String) -> V? {
        return NSKeyedUnarchiver.unarchiveObject(withFile: path) as? V
    }
    
    public func archive(with path: String, value: V) -> Bool {
        return NSKeyedArchiver.archiveRootObject(value, toFile: path)
    }
}
