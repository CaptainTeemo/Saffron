//
//  ImageCell.swift
//  CacheDemo
//
//  Created by Captain Teemo on 3/29/16.
//  Copyright © 2016 Captain Teemo. All rights reserved.
//

import UIKit
import Saffron

class ImageCell: UITableViewCell {

    @IBOutlet weak var demoImage: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .None
        
        let loader = DefaultAnimator(revealStyle: .Fade, reportProgress: true)
        demoImage.sf_setAnimationLoader(loader)
    }
    
    func configure(url: String) {
        demoImage.sf_setImage(url)
    }
}
