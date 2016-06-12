//
//  UIImageViewExtension.swift
//  Saffron
//
//  Created by Captain Teemo on 3/30/16.
//  Copyright © 2016 Captain Teemo. All rights reserved.
//

import Foundation

public extension UIImageView {
    /**
     Set image with url.
     
     - parameter url:         Image url.
     - parameter placeholder: Placeholder image.
     - parameter queryPolicy: Query policy, see `CacheQueryPolicy`.
     - parameter options:     Options to edit image, see `Option`.
     - parameter done:        Callback when done.
     */
    public func sf_setImage(url: String, placeholder: UIImage? = nil, queryPolicy: CacheQueryPolicy = .Normal, options: [Option]? = nil, done: ((UIImage?, NSError?) -> Void)? = nil) {
        
        let url = url.stringByReplacingOccurrencesOfString(" ", withString: "")
        
        sf_cancelDownload()
        
        Option.batch(placeholder, options: options) { (result) in
            self.image = result
        }
        
        ImageManager.sharedManager().fetch(url, queryPolicy: queryPolicy) { (image) in
            if let cachedImage = image {
                Option.batch(cachedImage, options: options, done: { (resultImage) in
                    self.image = resultImage
                    self._loadingAnimator?.removeAnimation()
                    done?(resultImage, nil)
                })
            } else {
                self.startLoadingAnimation()
                
                let task = ImageManager.sharedManager().downloadImage(
                    url,
                    progress: { (received, total) in
                        self._loadingAnimator?.progress?(received, total)
                    },
                    done: { (image, error) in
                        self._operations?.removeValueForKey(url)
                        if let downloadedImage = image {
                            Option.batch(downloadedImage, options: options, done: { (resultImage) in
                                self.image = resultImage
                            })
                            ImageManager.sharedManager().write(url, image: downloadedImage)
                            self.removeLoadingAnimation()
                        }
                        done?(image, error)
                })
                
                if self._operations == nil {
                    self._operations = [String: NSOperation]()
                }
                self._operations![url] = task
            }
        }
    }
    
    /**
     Cancel current download task.
     */
    public func sf_cancelDownload() {
        _operations?.forEach { $0.1.cancel() }
    }
    
    /**
     Use a custom image loader.
     
     - parameter loaderView: Custom loader view, it must conform protocol `LoadingAnimator`.
     */
    public func sf_setAnimationLoader<T: UIView where T: LoadingAnimator>(loaderView: T) {
        for subview in subviews {
            if subview is LoadingAnimator {
                subview.removeFromSuperview()
            }
        }
        
        loaderView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(loaderView)
        
        NSLayoutConstraint(
            item: loaderView,
            attribute: .Top,
            relatedBy: .Equal,
            toItem: self,
            attribute: .Top,
            multiplier: 1,
            constant: 0).active = true
        
        NSLayoutConstraint(
            item: loaderView,
            attribute: .Leading,
            relatedBy: .Equal,
            toItem: self,
            attribute: .Leading,
            multiplier: 1,
            constant: 0).active = true
        
        NSLayoutConstraint(
            item: loaderView,
            attribute: .Bottom,
            relatedBy: .Equal,
            toItem: self,
            attribute: .Bottom,
            multiplier: 1,
            constant: 0).active = true
        
        NSLayoutConstraint(
            item: loaderView,
            attribute: .Trailing,
            relatedBy: .Equal,
            toItem: self,
            attribute: .Trailing,
            multiplier: 1,
            constant: 0).active = true
        
        _loadingAnimator = loaderView
    }
}

private var animatorKey: Void?
private var operationKey: Void?

private extension UIImageView {
    
    private var _loadingAnimator: LoadingAnimator? {
        set {
            objc_setAssociatedObject(self, &animatorKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        get {
            return objc_getAssociatedObject(self, &animatorKey) as? LoadingAnimator
        }
    }
    
    private var _operations: [String: NSOperation]? {
        set {
            objc_setAssociatedObject(self, &operationKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        get {
            return objc_getAssociatedObject(self, &operationKey) as? [String: NSOperation]
        }
    }
    
    private func startLoadingAnimation() {
        _loadingAnimator?.startAnimation()
    }
    
    private func removeLoadingAnimation() {
        _loadingAnimator?.removeAnimation()
        _loadingAnimator?.reveal?()
    }
}