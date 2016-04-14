//
//  GifEncoder.swift
//  Saffron
//
//  Created by Captain Teemo on 3/30/16.
//  Copyright © 2016 Captain Teemo. All rights reserved.
//

// Thanks to https://github.com/bahlo/SwiftGif

import Foundation
import ImageIO

private var key: Void?

// MARK: GIF
extension UIImage {
    
    var gifData: NSData? {
        set {
            objc_setAssociatedObject(self, &key, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        get {
            return objc_getAssociatedObject(self, &key) as? NSData
        }
    }
    
    class func animatedGIF(data: NSData) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data, nil) else {
            return nil
        }
        return UIImage.animatedImage(source)
    }
    
    private class func delayForImageAtIndex(index: Int, source: CGImageSource!) -> Double {
        var delay = 0.1
        
        let cfProperties = CGImageSourceCopyPropertiesAtIndex(source, index, nil)
        
        let gifProperties = unsafeBitCast(CFDictionaryGetValue(cfProperties, unsafeAddressOf(kCGImagePropertyGIFDictionary)), CFDictionary.self)
        
        var delayObject = unsafeBitCast(CFDictionaryGetValue(gifProperties, unsafeAddressOf(kCGImagePropertyGIFUnclampedDelayTime)), AnyObject.self)
        
        if delayObject.doubleValue == 0 {
            delayObject = unsafeBitCast(CFDictionaryGetValue(gifProperties, unsafeAddressOf(kCGImagePropertyGIFDelayTime)), AnyObject.self)
        }
        
        delay = delayObject as! Double
        
        if delay < 0.1 {
            delay = 0.1
        }
        
        return delay
    }
    
    private class func gcdForPair(a: Int?, _ b: Int?) -> Int {
        var a = a
        var b = b
        // Check if one of them is nil
        if b == nil || a == nil {
            if b != nil {
                return b!
            } else if a != nil {
                return a!
            } else {
                return 0
            }
        }
        
        // Swap for modulo
        if a < b {
            let c = a
            a = b
            b = c
        }
        
        // Get greatest common divisor
        var rest: Int
        while true {
            rest = a! % b!
            
            if rest == 0 {
                return b! // Found it
            } else {
                a = b
                b = rest
            }
        }
    }
    
    private class func gcdForArray(array: [Int]) -> Int {
        if array.isEmpty {
            return 1
        }
        
        var gcd = array[0]
        
        for val in array {
            gcd = UIImage.gcdForPair(val, gcd)
        }
        
        return gcd
    }
    
    private class func animatedImage(source: CGImageSource) -> UIImage? {
        let count = CGImageSourceGetCount(source)
        
        if count <= 1 {
            return nil
        }
        
        var images = [CGImageRef]()
        var delays = [Int]()
        
        // Fill arrays
        for i in 0..<count {
            // Add image
            if let image = CGImageSourceCreateImageAtIndex(source, i, nil) {
                images.append(image)
            }
            
            // At it's delay in cs
            let delaySeconds = UIImage.delayForImageAtIndex(Int(i), source: source)
            delays.append(Int(delaySeconds * 1000.0)) // Seconds to ms
        }
        
        // Calculate full duration
        let duration: Int = {
            var sum = 0
            
            for val: Int in delays {
                sum += val
            }
            
            return sum
        }()
        
        // Get frames
        let gcd = gcdForArray(delays)
        var frames = [UIImage]()
        
        var frame: UIImage
        var frameCount: Int
        for i in 0..<count {
            frame = UIImage(CGImage: images[i])
            frameCount = Int(delays[i] / gcd)
            
            for _ in 0..<frameCount {
                frames.append(frame)
            }
        }
        
        let animation = UIImage.animatedImageWithImages(frames,
                                                        duration: Double(duration) / 1000.0)
        
        return animation
    }
    
    private class func decodeImage(image: UIImage) -> UIImage? {
        let imageRef = image.CGImage
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.PremultipliedFirst.rawValue | CGBitmapInfo.ByteOrder32Little.rawValue)
        
        guard let context = CGBitmapContextCreate(nil, CGImageGetWidth(imageRef), CGImageGetWidth(imageRef), 8, CGImageGetWidth(imageRef) * 4, colorSpace, bitmapInfo.rawValue) else { return nil }
        let rect = CGRect(origin: CGPointZero, size: CGSize(width: CGImageGetWidth(imageRef), height: CGImageGetHeight(imageRef)))
        CGContextDrawImage(context, rect, imageRef)
        
        guard let decompressedImageRef = CGBitmapContextCreateImage(context) else { return nil }
        
        let decompressedImage = UIImage(CGImage: decompressedImageRef)
        
        return decompressedImage
    }
}