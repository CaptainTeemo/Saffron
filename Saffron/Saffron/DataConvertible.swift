//
//  DataConvertible.swift
//  Saffron
//
//  Created by Captain Teemo on 3/29/16.
//  Copyright © 2016 Captain Teemo. All rights reserved.
//

import Foundation

public protocol DataConvertible {
    
    associatedtype Result
    
    func toData() -> NSData?
    static func fromData(data: NSData) -> Result?
}

extension String: DataConvertible {
    
    public typealias Result = String
    
    public func toData() -> NSData? {
        return self.dataUsingEncoding(NSUTF8StringEncoding)
    }
    
    public static func fromData(data: NSData) -> Result? {
        return String(data: data, encoding: NSUTF8StringEncoding)
    }
}

extension UIImage: DataConvertible {
    
    public typealias Result = UIImage
    
    public func toData() -> NSData? {
        if let data = gifData {
            return data
        }
        return UIImageJPEGRepresentation(self, 1)
    }
    
    public static func fromData(data: NSData) -> Result? {
        if let image = self.animatedGIF(data) {
            return image
        } else {
            return self.init(data: data)
        }
    }
}
