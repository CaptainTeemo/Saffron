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
     
     - parameter url:             Image url.
     - parameter placeholder:     Placeholder image.
     - parameter progressiveBlur: Show blur style progressive image.
     - parameter options:         Options to edit image, see `Option`.
     - parameter done:            Callback when done.
     */
    public func sf_setImage(_ url: URL, placeholder: UIImage? = nil, progressiveBlur: Bool = false, options: [Option]? = nil, done: ((UIImage?, NSError?) -> Void)? = nil) {
        
        sf_cancelDownload()
        
        Option.batch(placeholder, options: options) { (result) in
            self.image = result
        }
        
        if _cacheImage == nil {
            _cacheImage = [String: UIImage]()
        }
        
        ImageManager.shared.fetch(url.absoluteString) { (image) in
            if let cachedImage = image {
                Option.batch(cachedImage, options: options, done: { (resultImage) in
                    self.image = resultImage
                    self._loadingAnimator?.removeAnimation()
                    done?(resultImage, nil)
                })
            } else {
                self.startLoadingAnimation()
                
                var progressiveClosure: ((UIImage) -> Void)? = nil
                if progressiveBlur {
                    progressiveClosure = { image in
                        dispatchOnMain({
                            self.image = image
                        })
                    }
                }
                
                let task = ImageManager.shared.downloadImage(
                    url,
                    progress: { (received, total) in
                        self._loadingAnimator?.progress?(received, total)
                    },
                    progressiveImage: progressiveClosure,
                    done: { (image, error) in
                        let _ = self._operations?.removeValue(forKey: url.absoluteString)
                        if let downloadedImage = image {
                            Option.batch(downloadedImage, options: options, done: { (resultImage) in
                                self.image = resultImage
                            })
                            ImageManager.shared.write(url.absoluteString, image: downloadedImage)
                            
                            self.removeLoadingAnimation()
                            if !progressiveBlur {
                                self.reveal()
                            }
                        }
                        done?(image, error)
                })
                
                if self._operations == nil {
                    self._operations = [String: Operation]()
                }
                self._operations![url.absoluteString] = task
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
    public func sf_setAnimationLoader<T: UIView>(_ loaderView: T) where T: LoadingAnimator {
        for subview in subviews {
            if subview is LoadingAnimator {
                subview.removeFromSuperview()
            }
        }
        
        loaderView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(loaderView)
        
        NSLayoutConstraint(
            item: loaderView,
            attribute: .top,
            relatedBy: .equal,
            toItem: self,
            attribute: .top,
            multiplier: 1,
            constant: 0).isActive = true
        
        NSLayoutConstraint(
            item: loaderView,
            attribute: .leading,
            relatedBy: .equal,
            toItem: self,
            attribute: .leading,
            multiplier: 1,
            constant: 0).isActive = true
        
        NSLayoutConstraint(
            item: loaderView,
            attribute: .bottom,
            relatedBy: .equal,
            toItem: self,
            attribute: .bottom,
            multiplier: 1,
            constant: 0).isActive = true
        
        NSLayoutConstraint(
            item: loaderView,
            attribute: .trailing,
            relatedBy: .equal,
            toItem: self,
            attribute: .trailing,
            multiplier: 1,
            constant: 0).isActive = true
        
        _loadingAnimator = loaderView
    }
}

private var animatorKey: Void?
private var operationKey: Void?
private var cacheImageKey: Void?

private extension UIImageView {
    
    var _loadingAnimator: LoadingAnimator? {
        set {
            objc_setAssociatedObject(self, &animatorKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        get {
            return objc_getAssociatedObject(self, &animatorKey) as? LoadingAnimator
        }
    }
    
    var _operations: [String: Operation]? {
        set {
            objc_setAssociatedObject(self, &operationKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        get {
            return objc_getAssociatedObject(self, &operationKey) as? [String: Operation]
        }
    }
    
    var _cacheImage: [String: UIImage]? {
        set {
            objc_setAssociatedObject(self, &cacheImageKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        
        get {
            return objc_getAssociatedObject(self, &cacheImageKey) as? [String: UIImage]
        }
    }
    
    func startLoadingAnimation() {
        _loadingAnimator?.startAnimation()
    }
    
    func removeLoadingAnimation() {
        _loadingAnimator?.removeAnimation()
    }
    
    func reveal() {
        _loadingAnimator?.reveal?()
    }
}
