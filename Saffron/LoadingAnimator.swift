//
//  LoadingAnimator.swift
//  Saffron
//
//  Created by Captain Teemo on 3/30/16.
//  Copyright © 2016 Captain Teemo. All rights reserved.
//

import Foundation

/**
 *  Customized animator must conforms to this protocol.
 */
@objc public protocol LoadingAnimator {
    /**
     Start loading animation.
     */
    func startAnimation()
    /**
     Remove animations.
     */
    func removeAnimation()
    
    /**
     Report progress.
     */
    optional func progress(received: Int64, _ total: Int64)
    
    /**
     Perform animation when showing image.
     */
    optional func reveal()
}

private let minMargin: CGFloat = 100

/**
 Animation when showing image.
 */
public enum RevealStyle {
        /// Fade in effect.
    case Fade
        /// Circle mask effect.
    case Circle
        /// No effect.
    case None
}

/// Builtin loading animator.
public class DefaultAnimator: UIView {
    private let loaderLayer = CAShapeLayer()
    
    private let diameter: CGFloat = 50
    
    private var _reportProgress = false
    
    private var _lineWidth: CGFloat {
        return diameter / 25
    }
    
    private var _revealStyle: RevealStyle = .None
    
    /**
     Init
     
     - parameter loaderColor:    Optional loader color. Default is UIColor.redColor()
     - parameter revealStyle:    Choose your favorite style.
     - parameter reportProgress: If report download progress.
     
     - returns: Instance.
     */
    public init(loaderColor: UIColor = UIColor.redColor(), revealStyle: RevealStyle, reportProgress: Bool) {
        super.init(frame: CGRectZero)
        commonInit()
        _reportProgress = reportProgress
        _revealStyle = revealStyle
        loaderLayer.strokeColor = loaderColor.CGColor
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        commonInit()
    }
    
    /// Please use init(loaderColor:revealStyle:reportProgress:)
    required public init?(coder aDecoder: NSCoder) {
        fatalError("Please use init(loaderColor:revealStyle:reportProgress:)")
    }
    
    func commonInit() {
        loaderLayer.lineWidth = _lineWidth
        loaderLayer.fillColor = nil
        loaderLayer.strokeColor = UIColor.redColor().CGColor
        layer.addSublayer(loaderLayer)
    }
    
    /**
     Change frame here. Just ignore.
     */
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        loaderLayer.frame = CGRect(
            x: frame.width / 2 - diameter / 2,
            y: frame.height / 2 - diameter / 2,
            width: diameter,
            height: diameter
        )
        
        let path = UIBezierPath(ovalInRect: loaderLayer.bounds)
        loaderLayer.path = path.CGPath
    }
    
    private func addAnimation() {
        
        loaderLayer.strokeEnd = 1
        
        let rotation = CABasicAnimation(keyPath: "transform.rotation")
        rotation.fromValue = 0
        rotation.toValue = 2 * M_PI
        rotation.duration = 0.6
        rotation.repeatCount = .infinity
        loaderLayer.addAnimation(rotation, forKey: "rotation")
        
        let strokeStart = CABasicAnimation(keyPath: "strokeStart")
        strokeStart.repeatCount = Float.infinity
        strokeStart.duration = 0.6
        strokeStart.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        strokeStart.fromValue = 0.4
        strokeStart.toValue = 0.9
        strokeStart.autoreverses = true
        loaderLayer.addAnimation(strokeStart, forKey: "strokeStart")
    }
    
    func dismiss() {
        if _reportProgress {
            loaderLayer.strokeEnd = 0
        }
        loaderLayer.removeAllAnimations()
        hidden = true
        superview?.layer.mask = nil
    }
    
    func revealAnimation(style: RevealStyle) {
        if let imageView = superview {
            switch style {
            case .Circle:
                let maskLayer = CAShapeLayer()
                let fromPath = UIBezierPath(ovalInRect: CGRect(origin: imageView.center, size: CGSizeZero)).CGPath
                maskLayer.path = fromPath
                imageView.layer.mask = maskLayer
                
                let maskRadius = sqrt(imageView.center.x * imageView.center.x + imageView.center.y * imageView.center.y)
                let toPath = UIBezierPath(ovalInRect: CGRect(x: imageView.frame.width / 2 - maskRadius, y: imageView.frame.height / 2 - maskRadius, width: maskRadius * 2, height: maskRadius * 2)).CGPath
                
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                maskLayer.path = toPath
                CATransaction.commit()
                
                let revealAnimation = CABasicAnimation(keyPath: "path")
                revealAnimation.fromValue = fromPath
                revealAnimation.toValue = toPath
                revealAnimation.duration = 0.8
                revealAnimation.delegate = self
                
                maskLayer.addAnimation(revealAnimation, forKey: "reveal")
                
            case .Fade:
                imageView.alpha = 0
                UIView.animateWithDuration(0.8, animations: {
                    imageView.alpha = 1
                })
            case .None:
                break
            }
        }
    }
    
    func updateProgress(progress: CGFloat) {
        CATransaction.begin()
        loaderLayer.strokeEnd = progress
        CATransaction.commit()
    }
}

extension DefaultAnimator: LoadingAnimator {
    /**
     Start loading animation.
     */
    public func startAnimation() {
        hidden = false
        if _reportProgress {
            updateProgress(0.1)
        } else {
            addAnimation()
        }
    }
    
    /**
     Remove animations.
     */
    public func removeAnimation() {
        dismiss()
    }
    
    /**
     Handle progress things.
     
     - parameter received: Received bytes.
     - parameter total:    Total bytes.
     */
    public func progress(received: Int64, _ total: Int64) {
        if _reportProgress {
            let progress = CGFloat(received) / CGFloat(total)
            if progress >= 0.1 {
                updateProgress(progress)
            }
        }
    }
    
    /**
     Show image with animation.
     */
    public func reveal() {
       revealAnimation(_revealStyle)
    }
}

extension DefaultAnimator {
    /// This should not be public.
    override public func animationDidStop(anim: CAAnimation, finished flag: Bool) {
        superview?.layer.mask = nil
    }
}