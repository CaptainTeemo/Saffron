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

fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}


private var key: Void?

// MARK: GIF
extension UIImage {
    
    var gifData: Data? {
        set {
            objc_setAssociatedObject(self, &key, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        get {
            return objc_getAssociatedObject(self, &key) as? Data
        }
    }
    
        /// Image is animated or not.
    public var sf_isGIF: Bool {
        if let data = gifData, let source = CGImageSourceCreateWithData(data as CFData, nil) , CGImageSourceGetCount(source) > 1 {
            return true
        }
        return false
    }
    
    /**
     Encode gif image with data.
     
     - parameter data: Image data.
     
     - returns: Animated UIImage.
     */
    public class func animatedGIF(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let image = UIImage.animatedImage(source)
        image?.gifData = data
        return image
    }
    
    /**
     Get gif frames.
     
     - parameter data: Image data.
     
     - returns: Frames and duration.
     */
    public class func animatedFrames(_ data: Data) -> ([UIImage], Double) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return ([], 0) }
        return UIImage.frames(source)
    }
    
    fileprivate class func delayForImageAtIndex(_ index: Int, source: CGImageSource!) -> Double {
        var delay = 0.1
        
        let cfProperties = CGImageSourceCopyPropertiesAtIndex(source, index, nil)
        
        let gifProperties = unsafeBitCast(CFDictionaryGetValue(cfProperties, Unmanaged.passUnretained(kCGImagePropertyGIFDictionary).toOpaque()), to: CFDictionary.self)
        
        var delayObject = unsafeBitCast(CFDictionaryGetValue(gifProperties, Unmanaged.passUnretained(kCGImagePropertyGIFUnclampedDelayTime).toOpaque()), to: AnyObject.self)
        
        if delayObject.doubleValue == 0 {
            delayObject = unsafeBitCast(CFDictionaryGetValue(gifProperties, Unmanaged.passUnretained(kCGImagePropertyGIFDelayTime).toOpaque()), to: AnyObject.self)
        }
        
        delay = delayObject as! Double
        
//        if delay < 0.1 {
//            delay = 0.1
//        }
        
        return delay
    }
    
    fileprivate class func gcdForPair(_ a: Int?, _ b: Int?) -> Int {
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
    
    fileprivate class func gcdForArray(_ array: [Int]) -> Int {
        if array.isEmpty {
            return 1
        }
        
        var gcd = array[0]
        
        for val in array {
            gcd = UIImage.gcdForPair(val, gcd)
        }
        
        return gcd
    }
    
    fileprivate class func frames(_ source: CGImageSource) -> ([UIImage], Double) {
        let count = CGImageSourceGetCount(source)
        
        if count <= 1 {
            if let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                let image = UIImage(cgImage: cgImage)
                return ([image], 0)
            }
            return ([], 0)
        }
        
        var images = [CGImage]()
        var delays = [Double]()
        
        // Fill arrays
        for i in 0..<count {
            // Add image
            if let image = CGImageSourceCreateImageAtIndex(source, i, nil) {
                images.append(image)
            }
            
            // At it's delay in cs
            let delaySeconds = UIImage.delayForImageAtIndex(Int(i), source: source)
            delays.append(delaySeconds * 1000.0) // Seconds to ms
        }
        
        // Calculate full duration
        let duration: Double = {
            var sum: Double = 0
            
            for val in delays {
                sum += val
            }
            
            return sum
        }()
        
        // Get frames
        let gcd = gcdForArray(delays.map { Int($0) })
        var frames = [UIImage]()
        
        var frame: UIImage
        var frameCount: Int
        for i in 0..<count {
            frame = UIImage(cgImage: images[i])
            if let image = UIImage.decodeImage(frame) {
                frame = image
            }
            frameCount = Int(delays[i]) / gcd
            
            for _ in 0..<frameCount {
                frames.append(frame)
            }
        }
        
        return (frames, Double(duration) / 1000.0)
    }
    
    fileprivate class func animatedImage(_ source: CGImageSource) -> UIImage? {
        let (frames, duration) = UIImage.frames(source)
        let animatedImage = UIImage.animatedImage(with: frames, duration: duration)
        return animatedImage
    }
    
    class func decodeImage(_ image: UIImage?) -> UIImage? {
        guard let image = image else { return nil }
        let imageRef = image.cgImage
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        
        guard let context = CGContext(data: nil, width: imageRef!.width, height: imageRef!.height, bitsPerComponent: 8, bytesPerRow: imageRef!.width * 4, space: colorSpace, bitmapInfo: bitmapInfo.rawValue) else { return nil }
        let rect = CGRect(origin: CGPoint.zero, size: CGSize(width: imageRef!.width, height: imageRef!.height))
        context.draw(imageRef!, in: rect)
        
        guard let decompressedImageRef = context.makeImage() else { return nil }
        
        let decompressedImage = UIImage(cgImage: decompressedImageRef)
        
        return decompressedImage
    }
}
