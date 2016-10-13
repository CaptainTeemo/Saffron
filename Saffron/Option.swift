//
//  Option.swift
//  Saffron
//
//  Created by CaptainTeemo on 5/3/16.
//  Copyright © 2016 Captain Teemo. All rights reserved.
//

import Foundation
import ImageIO

private let processQueue = DispatchQueue(label: "com.teemo.suffron.options", attributes: DispatchQueue.Attributes.concurrent)

/**
 Options to edit image.
 
 - GaussianBlur: Blur effect.
 - CornerRadius: Round corner.
 - ScaleToFill:  Crop image to fit container size.
 - Oval: Crop image to oval.
 */
public enum Option {
    /**
     Pass a radius value.
     */
    case gaussianBlur(CGFloat)
    /**
     Corner radius might be different by image size.
     */
    case cornerRadius(CGFloat)
    /**
     Scale to fill container.
     */
    case scaleToFill(CGSize)
    /**
     Crop image to oval.
     */
    case oval
    
    fileprivate func handle(_ image: UIImage?, done: (UIImage?) -> Void) {
        switch self {
        case .gaussianBlur(let radius):
            done(image?.blur(with: radius))
        case .cornerRadius(let radius):
            done(image?.roundCorner(radius))
        case .scaleToFill(let size):
            done(image?.scaleToFill(size))
        case .oval:
            done(image?.oval())
        }
    }
    
    /**
     Perform batch operations, in order.
     Note: Animated UIImage would not be processed for now.
     
     - parameter image:   Input image.
     - parameter options: Things to deal with image.
     - parameter done:    Callback when done, in main thread.
     */
    public static func batch(_ image: UIImage?, options: [Option]?, done: @escaping (UIImage?) -> Void) {
        guard let options = options else {
            dispatchOnMain({ 
                done(image)
            })
            return
        }
        
        if let data = image?.gifData, let source = CGImageSourceCreateWithData(data as CFData, nil) {
            let count = CGImageSourceGetCount(source)
            if count > 1 {
                dispatchOnMain({
                    done(image)
                })
                return
            }
        }

        var resultImage = image
        let group = DispatchGroup()
        for option in options {
            group.enter()
            processQueue.async(flags: .barrier, execute: {
                option.handle(resultImage, done: { (output) in
                    resultImage = output
                    group.leave()
                })
            })
        }
        group.notify(queue: DispatchQueue.main) {
            done(resultImage)
        }
    }
}
