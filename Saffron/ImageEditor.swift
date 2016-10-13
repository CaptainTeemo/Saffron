//
//  ImageEditor.swift
//  Saffron
//
//  Created by CaptainTeemo on 5/3/16.
//  Copyright © 2016 Captain Teemo. All rights reserved.
//
import Accelerate

extension UIImage {
    func blur(with radius: CGFloat, iterations: Int = 2, ratio: CGFloat = 1.2, blendColor: UIColor? = nil) -> UIImage? {
        if floorf(Float(size.width)) * floorf(Float(size.height)) <= 0.0 || radius <= 0 {
            return self
        }
        var imageRef = cgImage
        
        if !isARGB8888(imageRef: imageRef!) {
            let context = createARGB8888BitmapContext(from: imageRef!)
            let rect = CGRect(x: 0, y: 0, width: imageRef!.width, height: imageRef!.height)
            context?.draw(imageRef!, in: rect)
            
            imageRef = context?.makeImage()
        }
        
        var boxSize = UInt32(radius * scale * ratio)
        if boxSize % 2 == 0 {
            boxSize += 1
        }
        
        let height = imageRef!.height
        let width = imageRef!.width
        let rowBytes = imageRef!.bytesPerRow
        let bytes = rowBytes * height
        
        let inData = malloc(bytes)
        var inBuffer = vImage_Buffer(data: inData, height: UInt(height), width: UInt(width), rowBytes: rowBytes)
        
        let outData = malloc(bytes)
        var outBuffer = vImage_Buffer(data: outData, height: UInt(height), width: UInt(width), rowBytes: rowBytes)
        
        let tempFlags = vImage_Flags(kvImageEdgeExtend + kvImageGetTempBufferSize)
        let tempSize = vImageBoxConvolve_ARGB8888(&inBuffer, &outBuffer, nil, 0, 0, boxSize, boxSize, nil, tempFlags)
        let tempBuffer = malloc(tempSize)
        
        let provider = imageRef!.dataProvider
        let copy = provider!.data
        let source = CFDataGetBytePtr(copy)
        memcpy(inBuffer.data, source, bytes)
        
        let flags = vImage_Flags(kvImageEdgeExtend)
        for _ in 0 ..< iterations {
            vImageBoxConvolve_ARGB8888(&inBuffer, &outBuffer, tempBuffer, 0, 0, boxSize, boxSize, nil, flags)
            
            let temp = inBuffer.data
            inBuffer.data = outBuffer.data
            outBuffer.data = temp
        }
        
        let colorSpace = imageRef!.colorSpace
        let bitmapInfo = imageRef!.bitmapInfo
        let bitmapContext = CGContext(data: inBuffer.data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: rowBytes, space: colorSpace!, bitmapInfo: bitmapInfo.rawValue)
        defer {
            free(outBuffer.data)
            free(tempBuffer)
            free(inBuffer.data)
        }
        
        if let color = blendColor {
            bitmapContext!.setFillColor(color.cgColor)
            bitmapContext!.setBlendMode(CGBlendMode.plusLighter)
            bitmapContext!.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        
        if let bitmap = bitmapContext!.makeImage() {
            return UIImage(cgImage: bitmap, scale: scale, orientation: imageOrientation)
        }
        
        return nil
    }
    
    private func isARGB8888(imageRef: CGImage) -> Bool {
        let alphaInfo = imageRef.alphaInfo
        let isAlphaOnFirstPlace = (CGImageAlphaInfo.first == alphaInfo || CGImageAlphaInfo.first == alphaInfo || CGImageAlphaInfo.noneSkipFirst == alphaInfo || CGImageAlphaInfo.noneSkipLast == alphaInfo)
        return imageRef.bitsPerPixel == 32 && imageRef.bitsPerComponent == 8 && (imageRef.bitmapInfo.rawValue & CGBitmapInfo.alphaInfoMask.rawValue) > 0 && isAlphaOnFirstPlace
    }
    
    private func createARGB8888BitmapContext(from image: CGImage) -> CGContext? {
        let pixelWidth = image.width
        let pixelHeight = image.height
        
        let bitmapBytesPerFow = pixelWidth * 4
        let bitmapByCount = bitmapBytesPerFow * pixelHeight
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        let bitmapData = UnsafeMutableRawPointer.allocate(bytes: bitmapByCount, alignedTo: bitmapByCount)
        let context = CGContext(data: bitmapData, width: pixelWidth, height: pixelHeight, bitsPerComponent: 8, bytesPerRow: bitmapBytesPerFow, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        return context
    }
    
    func roundCorner(_ radius: CGFloat) -> UIImage? {
        let rect = CGRect(origin: CGPoint.zero, size: size)
        
        UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
        let context = UIGraphicsGetCurrentContext()
        let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)
        context!.addPath(path.cgPath)
        context!.clip()
        draw(in: rect)
        
        let output = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return output
    }
    
    func oval() -> UIImage? {
        let rect = CGRect(origin: CGPoint.zero, size: size)
        
        UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
        let context = UIGraphicsGetCurrentContext()
        let path = UIBezierPath(ovalIn: rect)
        context!.addPath(path.cgPath)
        context!.clip()
        draw(in: rect)
        
        let output = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return output
    }
    
    func scaleToFill(_ targetSize: CGSize) -> UIImage {
        let targetAspect = targetSize.width / targetSize.height
        let aspect = size.width / size.height
        
        var scaledSize = size
        if targetAspect < aspect {
            scaledSize.width = ceil(size.height * targetAspect)
        } else {
            scaledSize.height = ceil(size.width * targetAspect)
        }
        
        let cropRect = CGRect(origin: CGPoint(x: -abs(size.width - scaledSize.width) / 2, y: -abs(size.height - scaledSize.height) / 2), size: scaledSize)
        
        UIGraphicsBeginImageContextWithOptions(scaledSize, false, UIScreen.main.nativeScale)
        let context = UIGraphicsGetCurrentContext()
        let path = UIBezierPath(rect: CGRect(origin: CGPoint.zero, size: size)).cgPath
        context!.addPath(path)
        context!.clip()
        draw(in: CGRect(origin: cropRect.origin, size: size))
        let output = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return output!
    }
}
