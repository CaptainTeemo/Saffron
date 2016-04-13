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
     - parameter done:        Callback closure.
     */
    public func sf_setImage(url: String, placeholder: UIImage? = nil, done: ((UIImage?, NSError?) -> Void)? = nil) {
        // loadingAnimator should not be nil, so we explictly unwrap it.
        if _loadingAnimator == nil {
            let animator = DefaultAnimator(reportProgress: true)
            sf_setAnimationLoader(animator)
        }
        
        image = _placeholder
        
        if let cachedImage = ImageManager.sharedManager().fetch(url) {
            image = cachedImage
            _loadingAnimator!.removeAnimation()
            done?(cachedImage, nil)
        } else {
            sf_cancelDownload()
            
            startLoadingAnimation()
            
            let task = ImageManager.sharedManager().downloadImage(
                url,
                progress: { [weak self] (received, total) in
                    self?._loadingAnimator!.progress?(received, total)
                },
                done: { [weak self] (image, error) in
                    self?._tasks?.removeValueForKey(url)
                    if let downloadedImage = image {
                        self?.image = downloadedImage
                        ImageManager.sharedManager().write(url, image: downloadedImage)
                        self?.removeLoadingAnimation()
                    }
                    
                    done?(image, error)
            })
            
            if _tasks == nil {
                _tasks = [String: NSOperation]()
            }
            _tasks?[url] = task
        }
    }
    
    /**
     Cancel current download task.
     */
    public func sf_cancelDownload() {
        _tasks?.forEach { $0.1.cancel() }
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

private var placeholderKey: Void?
private var animatorKey: Void?
private var taskKey: Void?

private extension UIImageView {
    
    private var _placeholder: UIImage? {
        set {
            objc_setAssociatedObject(self, &placeholderKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        get {
            return objc_getAssociatedObject(self, &placeholderKey) as? UIImage
        }
    }
    
    private var _loadingAnimator: LoadingAnimator? {
        set {
            objc_setAssociatedObject(self, &animatorKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        get {
            return objc_getAssociatedObject(self, &animatorKey) as? LoadingAnimator
        }
    }
    
    private var _tasks: [String: NSOperation]? {
        set {
            objc_setAssociatedObject(self, &taskKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        get {
            return objc_getAssociatedObject(self, &taskKey) as? [String: NSOperation]
        }
    }
    
    private func startLoadingAnimation() {
        _loadingAnimator!.startAnimation()
    }
    
    private func removeLoadingAnimation() {
        _loadingAnimator!.removeAnimation()
        _loadingAnimator!.reveal?()
    }
}