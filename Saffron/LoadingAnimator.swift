//
//  LoadingAnimator.swift
//  Saffron
//
//  Created by Captain Teemo on 3/30/16.
//  Copyright © 2016 Captain Teemo. All rights reserved.
//

import Foundation

@objc public protocol LoadingAnimator {
    func startAnimation()
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

enum RevealStyle {
    case Fade
    case Circle
    case None
}

public class DefaultAnimator: UIView {
    private let loaderLayer = CAShapeLayer()
    
    private let diameter: CGFloat = 50
    
    private var _reportProgress = false
    
    private var _lineWidth: CGFloat {
        return diameter / 25
    }
    
    public init(loaderColor: UIColor = UIColor.redColor(), reportProgress: Bool) {
        super.init(frame: CGRectZero)
        commonInit()
        _reportProgress = reportProgress
        loaderLayer.strokeColor = loaderColor.CGColor
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        commonInit()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        commonInit()
    }
    
    func commonInit() {
        loaderLayer.lineWidth = _lineWidth
        loaderLayer.fillColor = nil
        loaderLayer.strokeColor = UIColor.redColor().CGColor
        layer.addSublayer(loaderLayer)
    }
    
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
    public func startAnimation() {
        hidden = false
        if !_reportProgress {
            addAnimation()
        }
    }
    
    public func removeAnimation() {
        dismiss()
    }
    
    public func progress(received: Int64, _ total: Int64) {
        if _reportProgress {
            let progress = CGFloat(received) / CGFloat(total)
            updateProgress(progress)
        }
    }
    
    public func reveal() {
       revealAnimation(.Circle)
    }
}

extension DefaultAnimator {
    override public func animationDidStop(anim: CAAnimation, finished flag: Bool) {
        superview?.layer.mask = nil
    }
}