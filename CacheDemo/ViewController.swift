//
//  ViewController.swift
//  CacheDemo
//
//  Created by Captain Teemo on 3/29/16.
//  Copyright © 2016 Captain Teemo. All rights reserved.
//

import UIKit
import Saffron

class ViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    
    var refreshControl: UIRefreshControl!
    
    let imageUrls = [
        "http://www.sideshowtoy.com/wp-content/uploads/2015/12/marvel-iron-man-mark-xlvi-sixth-scale-captain-america-civil-war-hot-toys-thumb-902622.jpg",
        "http://www.androidpolice.com/wp-content/uploads/2015/05/nexus2cee_iron_man_by_rapsag-d65d74d.jpg",
        "http://images.techtimes.com/data/images/full/83428/iron-man.jpg?w=600",
        "http://images-cdn.moviepilot.com/images/c_fill,h_1200,w_1900/t_mp_quality/n4pywfe7qvf3hwf0bc4h/is-iron-man-becoming-marvel-s-greatest-villain-527622.jpg",
        "http://screenrant.com/wp-content/uploads/Iron-Man-Robert-Downey-Jr-Interview.jpg",
        "http://cdn.collider.com/wp-content/uploads/avengers-movie-image-iron-man-slice.jpg",
        "http://lovelace-media.imgix.net/uploads/249/3d37a870-3116-0132-0982-0eae5eefacd9.gif",
        "http://www.wired.com/images_blogs/photos/uncategorized/2008/07/18/iron_man_face.jpg",
        "http://www.push-start.co.uk/wp-content/uploads/2012/04/IronMan.jpg",
        "http://image.tianjimedia.com/uploadImages/2012/159/2YUO85971OV7_1000x500.jpg",
        "http://image.tianjimedia.com/uploadImages/2012/159/40S2O6S02ARH_1000x500.jpg",
        "http://image.tianjimedia.com/uploadImages/2012/159/GVK0IPD7MBO8_1000x500.jpg",
        "http://image.tianjimedia.com/uploadImages/2012/159/QL0J6027D4NN_1000x500.jpg",
        "http://image.tianjimedia.com/uploadImages/2012/159/9WYG9965EY9F_1000x500.jpg",
        "http://image.tianjimedia.com/uploadImages/2012/159/Q4PP87Q971GF_1000x500.jpg",
        "http://image.tianjimedia.com/uploadImages/2012/159/63WMF5LPVNBU_1000x500.jpg",
        "http://image.tianjimedia.com/uploadImages/2012/159/GY0588VFBGA9_1000x500.jpg",
        "http://image.tianjimedia.com/uploadImages/2012/159/U59ST295UVB6_1000x500.jpg",
        "http://image.tianjimedia.com/uploadImages/2012/159/LT4W8QEM549Z_1000x500.png",
        "http://image.tianjimedia.com/uploadImages/2012/159/7UXA6QR4G530_1000x500.jpg",
        "http://image.tianjimedia.com/uploadImages/2012/159/I6F1ST30D8BI_1000x500.jpg",
        "http://image.tianjimedia.com/uploadImages/2012/159/R87D0COR9L0K_1000x500.jpg",
        "http://image.tianjimedia.com/uploadImages/2012/159/YDLL743A63F2_1000x500.png",
        "http://image.tianjimedia.com/uploadImages/2012/159/VQ7Z1734AZ91_1000x500.jpg",
        "http://image.tianjimedia.com/uploadImages/2012/159/QVS16CHJI219_1000x500.jpg",
        "http://image.tianjimedia.com/uploadImages/2012/159/2SX444451436_1000x500.jpg",
        "http://image.tianjimedia.com/uploadImages/2012/159/I7CT36OLPIKQ_1000x500.jpg",
        "http://image.tianjimedia.com/uploadImages/2012/159/980O9402WSQ2_1000x500.jpg",
        "http://image.tianjimedia.com/uploadImages/2012/159/5927C3PW85UZ_1000x500.jpg",
        "http://image.tianjimedia.com/uploadImages/2012/159/1FF1ESH41RK2_1000x500.jpg",
        "http://image.tianjimedia.com/uploadImages/2012/159/RWS9KRJ03N1X_1000x500.jpg"
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.registerNib(ImageCell.nib(), forCellReuseIdentifier: ImageCell.reuseIdentifier())
        tableView.rowHeight = view.frame.width
        tableView.dataSource = self
        
        initRefreshControl()
    }
    
    func initRefreshControl() {
        refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(ViewController.refreshData), forControlEvents: .ValueChanged)
        tableView.addSubview(refreshControl)
    }
    
    func refreshData() {
        ImageManager.sharedManager().clearCache()
        tableView.reloadData()
        refreshControl.endRefreshing()
    }
}

extension ViewController: UITableViewDataSource {
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return imageUrls.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(ImageCell.reuseIdentifier(), forIndexPath: indexPath) as! ImageCell
        cell.configure(imageUrls[indexPath.row])
        return cell
    }
}

extension UIView {
    class func nib() -> UINib {
        return UINib(nibName: "\(self)", bundle: nil)
    }
    
    class func reuseIdentifier() -> String {
        return "\(self)"
    }
}

