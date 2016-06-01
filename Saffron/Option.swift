//
//  Option.swift
//  Saffron
//
//  Created by CaptainTeemo on 5/3/16.
//  Copyright © 2016 Captain Teemo. All rights reserved.
//

import Foundation

private let processQueue = dispatch_queue_create("com.teemo.suffron.options", DISPATCH_QUEUE_CONCURRENT)

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
    case GaussianBlur(CGFloat)
    /**
     Corner radius might be different by image size.
     */
    case CornerRadius(CGFloat)
    /**
     Scale to fill container.
     */
    case ScaleToFill(CGSize)
    /**
     Crop image to oval.
     */
    case Oval
    
    private func handle(image: UIImage?, done: (UIImage?) -> Void) {
        switch self {
        case .GaussianBlur(let radius):
            done(image?.blur(radius))
        case .CornerRadius(let radius):
            done(image?.roundCorner(radius))
        case .ScaleToFill(let size):
            done(image?.scaleToFill(size))
        case .Oval:
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
    public static func batch(image: UIImage?, options: [Option]?, done: (UIImage?) -> Void) {
        guard let options = options else {
            dispatchOnMain({ 
                done(image)
            })
            return
        }
        guard image?.gifData == nil else {
            dispatchOnMain({
                done(image)
            })
            return
        }
        var resultImage = image
        let group = dispatch_group_create()
        for option in options {
            dispatch_group_enter(group)
            dispatch_barrier_async(processQueue, {
                option.handle(resultImage, done: { (output) in
                    resultImage = output
                    dispatch_group_leave(group)
                })
            })
        }
        dispatch_group_notify(group, dispatch_get_main_queue()) {
            done(resultImage)
        }
    }
}