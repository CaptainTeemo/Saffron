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
    @objc optional func progress(_ received: Int64, _ total: Int64)
    
    /**
     Perform animation when showing image.
     */
    @objc optional func reveal()
}

private let minMargin: CGFloat = 100

/**
 Animation when showing image.
 */
public enum RevealStyle {
        /// Fadein effect with duration.
    case fade(TimeInterval)
        /// Circle mask effect.
    case circle
        /// No effect.
    case none
}

/**
 Animation when loading image.
 */
public enum AnimatorStyle {
        /// Looks like a Material-Design loader.
    case material
        /// No animator.
    case none
}

/// Builtin loading animator.
open class DefaultAnimator: UIView {
    fileprivate let loaderLayer = CAShapeLayer()
    
    fileprivate var _progressBackgroundLayer: CAShapeLayer?
    
    fileprivate let diameter: CGFloat = 50
    
    fileprivate var _reportProgress = false
    
    fileprivate var _lineWidth: CGFloat {
        return diameter / 25
    }
    
    fileprivate var _revealStyle: RevealStyle = .none

    fileprivate var _animatorStyle: AnimatorStyle = .material
    
    /**
     Init
     
     - parameter loaderColor:    Optional loader color. Default is UIColor.redColor()
     - parameter animatorStyle:  Animator loading style. If it's set to .None reportProgress will be ignored.
     - parameter revealStyle:    Choose your favorite style.
     - parameter reportProgress: If report download progress.
     
     - returns: Instance.
     */
    public init(loaderColor: UIColor = UIColor.red, animatorStyle: AnimatorStyle, revealStyle: RevealStyle, reportProgress: Bool) {
        super.init(frame: CGRect.zero)
        
        switch animatorStyle {
        case .material:
            loaderLayer.lineWidth = _lineWidth
            loaderLayer.fillColor = nil
            loaderLayer.strokeColor = UIColor.red.cgColor
            layer.addSublayer(loaderLayer)
        default:
            break
        }
        
        _reportProgress = reportProgress
        _revealStyle = revealStyle
        _animatorStyle = animatorStyle
        loaderLayer.strokeColor = loaderColor.cgColor
        
        if reportProgress {
            let progressBackgroundLayer = CAShapeLayer()
            progressBackgroundLayer.lineWidth = _lineWidth
            progressBackgroundLayer.fillColor = nil
            
            var red: CGFloat = 0, blue: CGFloat = 0, green: CGFloat = 0, alpha: CGFloat = 0
            loaderColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            progressBackgroundLayer.strokeColor = UIColor(red: red, green: green, blue: blue, alpha: alpha / 4).cgColor
            
            layer.addSublayer(progressBackgroundLayer)
            
            _progressBackgroundLayer = progressBackgroundLayer
        }
    }
    
    fileprivate override init(frame: CGRect) {
        super.init(frame: frame)
        
    }
    
    /// Please use init(loaderColor:revealStyle:reportProgress:)
    required public init?(coder aDecoder: NSCoder) {
        fatalError("Please use init(loaderColor:revealStyle:reportProgress:)")
    }
    
    /**
     Change frame here. Just ignore.
     */
    override open func layoutSubviews() {
        super.layoutSubviews()
        
        loaderLayer.frame = CGRect(
            x: frame.width / 2 - diameter / 2,
            y: frame.height / 2 - diameter / 2,
            width: diameter,
            height: diameter
        )
        
        let path = UIBezierPath(arcCenter: CGPoint(x: loaderLayer.frame.width / 2, y: loaderLayer.frame.height / 2), radius: diameter / 2, startAngle: -CGFloat(M_PI_2), endAngle: CGFloat(3 * M_PI_2), clockwise: true)
        loaderLayer.path = path.cgPath
        
        _progressBackgroundLayer?.frame = loaderLayer.frame
        
        if let _ = _progressBackgroundLayer {
            let bgPath = UIBezierPath(ovalIn: loaderLayer.bounds)
            _progressBackgroundLayer?.path = bgPath.cgPath
        }
    }
    
    fileprivate func addAnimation() {
        loaderLayer.strokeStart = 0
        loaderLayer.strokeEnd = 1
        
        let rotation = CABasicAnimation(keyPath: "transform.rotation")
        rotation.fromValue = 0
        rotation.toValue = 2 * M_PI
        rotation.duration = 0.6
        rotation.repeatCount = .infinity
        loaderLayer.add(rotation, forKey: "rotation")
        
        let strokeStart = CABasicAnimation(keyPath: "strokeStart")
        strokeStart.repeatCount = Float.infinity
        strokeStart.duration = 0.6
        strokeStart.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        strokeStart.fromValue = 0.4
        strokeStart.toValue = 0.9
        strokeStart.autoreverses = true
        loaderLayer.add(strokeStart, forKey: "strokeStart")
    }
    
    func dismiss() {
        if _reportProgress {
            loaderLayer.strokeEnd = 0
        }
        loaderLayer.removeAllAnimations()
        isHidden = true
        superview?.layer.mask = nil
    }
    
    func revealAnimation(_ style: RevealStyle) {
        if let imageView = superview {
            switch style {
            case .circle:
                let maskLayer = CAShapeLayer()
                let fromPath = UIBezierPath(ovalIn: CGRect(origin: imageView.center, size: CGSize.zero)).cgPath
                maskLayer.path = fromPath
                imageView.layer.mask = maskLayer
                
                let maskRadius = sqrt(imageView.center.x * imageView.center.x + imageView.center.y * imageView.center.y)
                let toPath = UIBezierPath(ovalIn: CGRect(x: imageView.frame.width / 2 - maskRadius, y: imageView.frame.height / 2 - maskRadius, width: maskRadius * 2, height: maskRadius * 2)).cgPath
                
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                maskLayer.path = toPath
                CATransaction.commit()
                
                let revealAnimation = CABasicAnimation(keyPath: "path")
                revealAnimation.fromValue = fromPath
                revealAnimation.toValue = toPath
                revealAnimation.duration = 0.8
//                revealAnimation.delegate = self
                
                maskLayer.add(revealAnimation, forKey: "reveal")
                
            case .fade(let duration):
                imageView.alpha = 0
                UIView.animate(withDuration: duration, animations: {
                    imageView.alpha = 1
                })
            case .none:
                break
            }
        }
    }
    
    func updateProgress(_ progress: CGFloat) {
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
        switch _animatorStyle {
        case .material:
            isHidden = false
            if _reportProgress {
                updateProgress(0.1)
            } else {
                addAnimation()
            }
        default:
            break
        }

    }
    
    /**
     Remove animations.
     */
    public func removeAnimation() {
        switch _animatorStyle {
        case .material:
            dismiss()
        default:
            break
        }
    }
    
    /**
     Handle progress things.
     
     - parameter received: Received bytes.
     - parameter total:    Total bytes.
     */
    public func progress(_ received: Int64, _ total: Int64) {
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
//    override public func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
//        superview?.layer.mask = nil
//    }
}
