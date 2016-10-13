//
//  ProgressiveImage.swift
//  Saffron
//
//  Created by CaptainTeemo on 6/17/16.
//  Copyright © 2016 Captain Teemo. All rights reserved.
//

import Foundation
import Accelerate
import ImageIO

// This progressiveImage idea is totally cribbed from PINRemoteImage(https://github.com/pinterest/PINRemoteImage) with one little modification which is I prefer dispatch_semaphore instead of NSLock.

final class ProgressiveImage {
    var progressThresholds: [CGFloat] {
        set {
            lock()
                _progressThresholds = newValue
            unlock()
        }
        
        get {
            lock()
                let thresholds = _progressThresholds
            unlock()
            return thresholds
        }
    }
    
    var estimatedRemainingTimeThreshold: Double {
        set {
            lock()
                _estimatedRemainingTimeThreshold = newValue
            unlock()
        }
        
        get {
            lock()
                let thresholds = _estimatedRemainingTimeThreshold
            unlock()
            return thresholds
        }
    }
    
    var startTime: Double {
        set {
            lock()
                _startTime = newValue
            unlock()
        }
        
        get {
            lock()
                let time = _startTime
            unlock()
            return time
        }
    }
    
//    var data: Data? {
//        get {
//            lock()
//                let data = _mutableData?.copy() as? Data
//            unlock()
//            return data
//        }
//    }
    
    fileprivate var _imageSource = CGImageSourceCreateIncremental(nil)
    fileprivate var _size = CGSize.zero
    fileprivate var _isProgressiveJPEG = true
    fileprivate var _progressThresholds: [CGFloat] = [0.00, 0.20, 0.35, 0.50, 0.65, 0.80]
    fileprivate var _currentThreshold = 0
    fileprivate var _startTime = CACurrentMediaTime()
    fileprivate var _estimatedRemainingTimeThreshold: Double = -1
    fileprivate var _sosCount = 0
    fileprivate var _scannedByte = 0
    fileprivate var _mutableData: Data?
    fileprivate var _expectedNumberOfBytes: Int64 = 0
    fileprivate var _bytesPerSecond: Double {
        get {
            let length = CACurrentMediaTime() - _startTime
            return Double(_mutableData!.count) / length
        }
    }
    fileprivate var _estimatedRemainingTime: Double {
        get {
            if _expectedNumberOfBytes < 0 { return Double(CGFloat.greatestFiniteMagnitude) }
            
            let remainingBytes = _expectedNumberOfBytes - _mutableData!.count
            if remainingBytes == 0 { return 0 }
            
            if _bytesPerSecond == 0 { return Double(CGFloat.greatestFiniteMagnitude) }
            
            return Double(remainingBytes) / _bytesPerSecond
        }
    }
    fileprivate var _semaphore = DispatchSemaphore(value: 1)
}

// MARK: - Public
extension ProgressiveImage {
    func updateProgressiveImage(_ data: Data, expectedNumberOfBytes: Int64) {
        lock()
        if _mutableData == nil {
            var bytesToAlloc = 0
            if expectedNumberOfBytes > 0 {
                bytesToAlloc = Int(expectedNumberOfBytes)
            }
            _mutableData = Data(capacity: bytesToAlloc)
            _expectedNumberOfBytes = expectedNumberOfBytes
        }
        _mutableData!.append(data)
        
        while !hasCompletedFirstScan() && _scannedByte < _mutableData!.count {
            var startByte = _scannedByte
            if startByte > 0 {
                startByte -= 1
            }
            
            let (found, scannedByte) = scanForSOS(_mutableData! as Data, startByte: startByte)
            if found {
                _sosCount += 1
            }
            _scannedByte = scannedByte
        }
        
        let _ = _mutableData!.withUnsafeBytes {
            CGImageSourceUpdateData(_imageSource, CFDataCreate(kCFAllocatorDefault, $0, _mutableData!.count), false)
        }
        
//        CGImageSourceUpdateData(_imageSource, CFDataCreate(kCFAllocatorDefault, _mutableData!.bytes.bindMemory(to: UInt8.self, capacity: _mutableData!.count), _mutableData!.count), false)
        
        unlock()
    }
    
    func currentImage(_ blurred: Bool, maxProgressiveRenderSize: CGSize = CGSize(width: 1024, height: 1024), quality: CGFloat = 1) -> UIImage? {
        lock()
        if _currentThreshold == _progressThresholds.count {
            unlock()
            return nil
        }
        
        if _estimatedRemainingTimeThreshold > 0 && _estimatedRemainingTime < _estimatedRemainingTimeThreshold {
            unlock()
            return nil
        }
        
        if !hasCompletedFirstScan() {
            unlock()
            return nil
        }
        
        var currentImage: UIImage? = nil
        
        if _size.width <= 0 || _size.height <= 0 {
            if let imageProperties = CGImageSourceCopyPropertiesAtIndex(_imageSource, 0, nil) as NSDictionary? {
                var size = _size
                if let width = imageProperties["\(kCGImagePropertyPixelWidth)"] , size.width <= 0 {
                    size.width = CGFloat(width as! NSNumber)
                }
                if let height = imageProperties["\(kCGImagePropertyPixelHeight)"] , size.height <= 0 {
                    size.height = CGFloat(height as! NSNumber)
                }
                
                _size = size
                
                if let jpegProperties = imageProperties["\(kCGImagePropertyJFIFDictionary)"] as? NSDictionary,
                    let isProgressive = jpegProperties["\(kCGImagePropertyJFIFIsProgressive)"] as? NSNumber {
                    _isProgressiveJPEG = isProgressive.boolValue
                }
            }
        }
        
        if _size.width > maxProgressiveRenderSize.width || _size.height > maxProgressiveRenderSize.height {
            unlock()
            return nil
        }
        
        var progress: CGFloat = 0
        if _expectedNumberOfBytes > 0 {
            progress = CGFloat(_mutableData!.count) / CGFloat(_expectedNumberOfBytes)
        }
        
        if progress >= 0.99 {
            unlock()
            return nil
        }
        
        if _isProgressiveJPEG && _size.width > 0 && _size.height > 0 && progress > _progressThresholds[_currentThreshold] {
            while _currentThreshold < _progressThresholds.count && progress > _progressThresholds[_currentThreshold] {
                _currentThreshold += 1
            }
            
            if let image = CGImageSourceCreateImageAtIndex(_imageSource, 0, nil) {
                if blurred {
                    currentImage = processImage(UIImage(cgImage: image), progress: progress)
                } else {
                    currentImage = UIImage(cgImage: image)
                }
            }
        }
        
        unlock()
        
        return currentImage
    }
}

// MARK: - Private
extension ProgressiveImage {
    fileprivate func scanForSOS(_ data: Data, startByte: Int) -> (Bool, Int) {
        let scanMarker = UnsafeMutableRawPointer(mutating: [0xFF, 0xDA])
//        var scanRange = NSRange()
//        scanRange.location = startByte
//        scanRange.length = data.count - scanRange.location
        let scanRange: Range<Int> = startByte..<data.count
        let sosRange = data.range(of: Data(bytes: UnsafeRawPointer(scanMarker), count: 2), options: .backwards, in: scanRange)
        if let r = sosRange, !r.isEmpty {
            return (true, (r.upperBound - r.lowerBound))
        }
        return (false, (scanRange.upperBound - scanRange.lowerBound))
    }
    
    fileprivate func hasCompletedFirstScan() -> Bool {
        return _sosCount >= 2
    }
    
    fileprivate func processImage(_ inputImage: UIImage, progress: CGFloat) -> UIImage? {
        guard let inputImageRef = inputImage.cgImage else { return nil }
        
        var outputImage: UIImage? = nil
        
        let inputSize = inputImage.size
        guard inputSize.width >= 1 || inputSize.height >= 1 else { return nil }
        
        let imageScale = inputImage.scale
        var radius = (inputImage.size.width / 25) * max(0, 1 - progress)
        radius *= imageScale
        
        if radius < CGFloat(FLT_EPSILON) {
            return inputImage
        }
        
        UIGraphicsBeginImageContextWithOptions(inputSize, true, imageScale)
        if let context = UIGraphicsGetCurrentContext() {
            context.scaleBy(x: 1, y: -1)
            context.translateBy(x: 0, y: -inputSize.height)
            
            var effectInBuffer = vImage_Buffer()
            var scratchBuffer = vImage_Buffer()
            
            var inputBuffer: vImage_Buffer
            var outputBuffer: vImage_Buffer
            
            var format = vImage_CGImageFormat(bitsPerComponent: 8, bitsPerPixel: 32, colorSpace: nil, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
                .union(.byteOrder32Little), version: 0, decode: nil, renderingIntent: CGColorRenderingIntent.defaultIntent)
            
            var error = vImageBuffer_InitWithCGImage(&effectInBuffer, &format, nil, inputImageRef, UInt32(kvImagePrintDiagnosticsToConsole))
            
            if error == kvImageNoError {
                error = vImageBuffer_Init(&scratchBuffer, effectInBuffer.height, effectInBuffer.width, format.bitsPerPixel, UInt32(kvImageNoFlags))
                if error == kvImageNoError {
                    inputBuffer = effectInBuffer
                    outputBuffer = scratchBuffer
                    
                    if radius - 2 < CGFloat(FLT_EPSILON) {
                        radius = 2
                    }
                    let d = radius * 3 * sqrt(2 * CGFloat(M_PI)) / 4 + 0.5
                    var wholeRadius = UInt32(floor(d / 2))
                    wholeRadius |= 1
                    
                    let tempBufferSize = vImageBoxConvolve_ARGB8888(&inputBuffer, &outputBuffer, nil, 0, 0, wholeRadius, wholeRadius, nil, UInt32(kvImageGetTempBufferSize) | UInt32(kvImageEdgeExtend))
                    
                    let tempBuffer: UnsafeMutableRawPointer? = malloc(tempBufferSize)
                    
                    if tempBuffer != nil {
                        vImageBoxConvolve_ARGB8888(&inputBuffer, &outputBuffer, tempBuffer, 0, 0, wholeRadius, wholeRadius, nil, UInt32(kvImageEdgeExtend))
                        vImageBoxConvolve_ARGB8888(&outputBuffer, &inputBuffer, tempBuffer, 0, 0, wholeRadius, wholeRadius, nil, UInt32(kvImageEdgeExtend))
                        vImageBoxConvolve_ARGB8888(&inputBuffer, &outputBuffer, tempBuffer, 0, 0, wholeRadius, wholeRadius, nil, UInt32(kvImageEdgeExtend))
                        
                        free(tempBuffer)
                        
                        let temp = inputBuffer
                        inputBuffer = outputBuffer
                        outputBuffer = temp
                        
                        if let effectCGImage = vImageCreateCGImageFromBuffer(&inputBuffer, &format, { userData, bufferData in
                            free(bufferData)
                            }, nil, UInt32(kvImageNoAllocate), nil) {
                            context.saveGState()
                            context.draw(effectCGImage.takeRetainedValue(), in: CGRect(x: 0, y: 0, width: inputSize.width, height: inputSize.height))
                        } else {
                            free(inputBuffer.data)
                        }
                        
                        free(outputBuffer.data)
                        
                        outputImage = UIGraphicsGetImageFromCurrentImageContext()
                    }
                } else {
                    if scratchBuffer.data != nil {
                        free(scratchBuffer.data)
                    }
                    free(effectInBuffer.data)
                }
            } else {
                if effectInBuffer.data != nil {
                    free(effectInBuffer.data)
                }
            }
        }
        
        UIGraphicsEndImageContext()
        
        return outputImage
    }
}

// MARK: - Lock
extension ProgressiveImage {
    fileprivate func lock() {
        let _ = _semaphore.wait(timeout: DispatchTime.distantFuture)
    }
    
    fileprivate func unlock() {
        _semaphore.signal()
    }
}
