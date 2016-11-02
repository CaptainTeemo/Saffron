//
//  ImageCacheRecorder.swift
//  Saffron
//
//  Created by CaptainTeemo on 11/2/16.
//  Copyright © 2016 Captain Teemo. All rights reserved.
//

import Foundation

extension CacheRecorder where Self.T: UIImage {
    typealias Image = T
    
    func unarchive(with path: String) -> Image? {
        if let data = FileManager.default.contents(atPath: path) {
            return UIImage.animatedGIF(data) as? Self.T
        }
        return nil
    }
    
    func archive(with path: String, value: Image) -> Bool {
        return FileManager.default.createFile(atPath: path, contents: value.sf_isGIF ? value.gifData : UIImagePNGRepresentation(value), attributes: nil)
    }
}
