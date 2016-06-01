//
//  ImageEditor.swift
//  Saffron
//
//  Created by CaptainTeemo on 5/3/16.
//  Copyright © 2016 Captain Teemo. All rights reserved.
//
import Accelerate

extension UIImage {
    
    func blur(radius: CGFloat, iterations: Int = 2, ratio: CGFloat = 1.2, blendColor: UIColor? = nil) -> UIImage? {
        if floorf(Float(size.width)) * floorf(Float(size.height)) <= 0.0 || radius <= 0 {
            return self
        }
        let imageRef = CGImage
        var boxSize = UInt32(radius * scale * ratio)
        if boxSize % 2 == 0 {
            boxSize += 1
        }
        
        let height = CGImageGetHeight(imageRef)
        let width = CGImageGetWidth(imageRef)
        let rowBytes = CGImageGetBytesPerRow(imageRef)
        let bytes = rowBytes * height
        
        let inData = malloc(bytes)
        var inBuffer = vImage_Buffer(data: inData, height: UInt(height), width: UInt(width), rowBytes: rowBytes)
        
        let outData = malloc(bytes)
        var outBuffer = vImage_Buffer(data: outData, height: UInt(height), width: UInt(width), rowBytes: rowBytes)
        
        let tempFlags = vImage_Flags(kvImageEdgeExtend + kvImageGetTempBufferSize)
        let tempSize = vImageBoxConvolve_ARGB8888(&inBuffer, &outBuffer, nil, 0, 0, boxSize, boxSize, nil, tempFlags)
        let tempBuffer = malloc(tempSize)
        
        let provider = CGImageGetDataProvider(imageRef)
        let copy = CGDataProviderCopyData(provider)
        let source = CFDataGetBytePtr(copy)
        memcpy(inBuffer.data, source, bytes)
        
        let flags = vImage_Flags(kvImageEdgeExtend)
        for _ in 0 ..< iterations {
            vImageBoxConvolve_ARGB8888(&inBuffer, &outBuffer, tempBuffer, 0, 0, boxSize, boxSize, nil, flags)
            
            let temp = inBuffer.data
            inBuffer.data = outBuffer.data
            outBuffer.data = temp
        }
        
        let colorSpace = CGImageGetColorSpace(imageRef)
        let bitmapInfo = CGImageGetBitmapInfo(imageRef)
        let bitmapContext = CGBitmapContextCreate(inBuffer.data, width, height, 8, rowBytes, colorSpace, bitmapInfo.rawValue)
        defer {
            free(outBuffer.data)
            free(tempBuffer)
            free(inBuffer.data)
        }
        
        if let color = blendColor {
            CGContextSetFillColorWithColor(bitmapContext, color.CGColor)
            CGContextSetBlendMode(bitmapContext, CGBlendMode.PlusLighter)
            CGContextFillRect(bitmapContext, CGRect(x: 0, y: 0, width: width, height: height))
        }
        
        if let bitmap = CGBitmapContextCreateImage(bitmapContext) {
            return UIImage(CGImage: bitmap, scale: scale, orientation: imageOrientation)
        }
        
        return nil
    }
    
    func roundCorner(radius: CGFloat) -> UIImage? {
        let rect = CGRect(origin: CGPointZero, size: size)
        
        UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.mainScreen().scale)
        let context = UIGraphicsGetCurrentContext()
        let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)
        CGContextAddPath(context, path.CGPath)
        CGContextClip(context)
        drawInRect(rect)
        
        let output = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return output
    }
    
    func oval() -> UIImage? {
        let rect = CGRect(origin: CGPointZero, size: size)
        
        UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.mainScreen().scale)
        let context = UIGraphicsGetCurrentContext()
        let path = UIBezierPath(ovalInRect: rect)
        CGContextAddPath(context, path.CGPath)
        CGContextClip(context)
        drawInRect(rect)
        
        let output = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return output
    }
    
    func scaleToFill(targetSize: CGSize) -> UIImage {
        let targetAspect = targetSize.width / targetSize.height
        let aspect = size.width / size.height
        
        var scaledSize = size
        if targetAspect < aspect {
            scaledSize.width = ceil(size.height * targetAspect)
        } else {
            scaledSize.height = ceil(size.width * targetAspect)
        }
        
        let cropRect = CGRect(origin: CGPoint(x: -abs(size.width - scaledSize.width) / 2, y: -abs(size.height - scaledSize.height) / 2), size: scaledSize)
        
        UIGraphicsBeginImageContextWithOptions(scaledSize, false, UIScreen.mainScreen().nativeScale)
        let context = UIGraphicsGetCurrentContext()
        let path = UIBezierPath(rect: CGRect(origin: CGPointZero, size: size)).CGPath
        CGContextAddPath(context, path)
        CGContextClip(context)
        drawInRect(CGRect(origin: cropRect.origin, size: size))
        let output = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return output
    }
}