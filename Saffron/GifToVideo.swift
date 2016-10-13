//
//  GifToVideo.swift
//  Saffron
//
//  Created by CaptainTeemo on 7/17/16.
//  Copyright © 2016 Captain Teemo. All rights reserved.
//

import Foundation
import AVFoundation

public final class GifToVideo: NSObject {
    fileprivate let gifQueue = DispatchQueue(label: "com.saffron.gifToVideo", attributes: DispatchQueue.Attributes.concurrent)
    
    fileprivate static let instance = GifToVideo()
    
    fileprivate var done: ((String) -> Void)?
    
    /**
     Convert gif image to video.
     
     - parameter gifImage:      A UIImage contains gif data.
     - parameter saveToLibrary: Save to library or not.
     - parameter done:          Callback with video path when convert finished.
     */
    public class func convert(_ gifImage: UIImage, saveToLibrary: Bool = true, done: ((String) -> Void)? = nil) throws {
        try instance.convertToVideo(gifImage, saveToLibrary: saveToLibrary, done: done)
    }
        
    fileprivate func convertToVideo(_ gifImage: UIImage, saveToLibrary: Bool = true, done: ((String) -> Void)? = nil) throws {
        guard let data = gifImage.gifData else {
            throw Error.error(-100, description: "Gif data is nil.")
        }
        self.done = done
        let (frames, duration) = UIImage.animatedFrames(data)
        
        let tempPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] + "/temp.mp4"
        
        if FileManager.default.fileExists(atPath: tempPath) {
            try FileManager.default.removeItem(atPath: tempPath)
        }
        
        let writer = try AVAssetWriter(outputURL: URL(fileURLWithPath: tempPath), fileType: AVFileTypeQuickTimeMovie)
        
        let settings: [String: AnyObject] = [AVVideoCodecKey: AVVideoCodecH264 as AnyObject,
                                             AVVideoWidthKey: gifImage.size.width as AnyObject,
                                             AVVideoHeightKey: gifImage.size.height as AnyObject]
        
        let input = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: settings)
        guard writer.canAdd(input) else {
            fatalError("cannot add input")
        }
        writer.add(input)
        
        let sourceBufferAttributes: [String : AnyObject] = [
            kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_32ARGB) as AnyObject,
            kCVPixelBufferWidthKey as String : gifImage.size.width as AnyObject,
            kCVPixelBufferHeightKey as String : gifImage.size.height as AnyObject]
        
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: sourceBufferAttributes)
        
        writer.startWriting()
        writer.startSession(atSourceTime: kCMTimeZero)
        
        let fps = Int32(Double(frames.count) / duration)
        let frameDuration = CMTimeMake(1, fps)
        var frameCount = 0
        
        input.requestMediaDataWhenReady(on: gifQueue, using: {
            while input.isReadyForMoreMediaData && frameCount < frames.count {
                let lastFrameTime = CMTimeMake(Int64(frameCount), fps)
                let presentationTime = frameCount == 0 ? lastFrameTime : CMTimeAdd(lastFrameTime, frameDuration)
                let image = frames[frameCount]
                
                do {
                    try self.appendPixelBuffer(image, adaptor: pixelBufferAdaptor, presentationTime: presentationTime)
                } catch let error as NSError {
                    fatalError(error.localizedDescription)
                }
                
                frameCount += 1
            }
            
            if (frameCount >= frames.count) {
                input.markAsFinished()
                writer.finishWriting {
                    dispatchOnMain {
                        if (writer.error != nil) {
                            print("Error converting images to video: \(writer.error)")
                        } else {
                            if saveToLibrary {
                                UISaveVideoAtPathToSavedPhotosAlbum(tempPath, self, #selector(self.video), nil)
                            } else {
                                done?(tempPath)
                            }
                        }
                    }
                }
            }
        })
    }
    
    fileprivate func appendPixelBuffer(_ image: UIImage, adaptor: AVAssetWriterInputPixelBufferAdaptor, presentationTime: CMTime) throws {
        if let pixelBufferPool = adaptor.pixelBufferPool {
            let pixelBufferPointer = UnsafeMutablePointer<CVPixelBuffer?>.allocate(capacity: 1)
            let status: CVReturn = CVPixelBufferPoolCreatePixelBuffer(
                kCFAllocatorDefault,
                pixelBufferPool,
                pixelBufferPointer
            )
            
            if let pixelBuffer = pixelBufferPointer.pointee, status == 0 {
                CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
                let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer)
                let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
                
                // Create CGBitmapContext
                let context = CGContext(
                    data: pixelData,
                    width: Int(image.size.width),
                    height: Int(image.size.height),
                    bitsPerComponent: 8,
                    bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                    space: rgbColorSpace,
                    bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                )
                
                // Draw image into context
                if let cgImage = image.cgImage {
                    context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
                }
                
                CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
                adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                pixelBufferPointer.deinitialize()
            } else {
                throw Error.error(-100, description: "Error: Failed to allocate pixel buffer from pool.")
            }
            
            pixelBufferPointer.deallocate(capacity: 1)
        }
    }
    
    //  - (void)video:(NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo;
    @objc fileprivate func video(_ videoPath: String, didFinishSavingWithError: NSError, contextInfo: UnsafeMutableRawPointer) {
        done?(videoPath)
    }
}
