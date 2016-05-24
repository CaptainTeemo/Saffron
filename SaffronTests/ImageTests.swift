//
//  ImageTests.swift
//  Saffron
//
//  Created by Captain Teemo on 4/8/16.
//  Copyright © 2016 Captain Teemo. All rights reserved.
//

import XCTest
@testable import Saffron

class ImageTests: XCTestCase {
    
    let testUrl = "http://lovelace-media.imgix.net/uploads/249/3d37a870-3116-0132-0982-0eae5eefacd9.gif"
    
    lazy var image: UIImage? = {
        let path = NSBundle(forClass: self.dynamicType).pathForResource("Teemo", ofType: "jpg")
        let image = UIImage(contentsOfFile: path!)
        return image
    }()

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testImageDownloadAndCache() {
        let testExpectation = self.expectationWithDescription("downloadAndCache")
        let url = testUrl
        
        ImageManager.sharedManager().downloadImage(url) { (image, error) in
            XCTAssertTrue(error == nil, "error: \(error)")
            if let image = image {
                ImageManager.sharedManager().write(url, image: image) { (finished) -> Void in
                    
                    XCTAssertTrue(finished)
                    
                    let memoryCache = ImageManager.sharedManager().fetchMemory(url)
                    XCTAssertNotNil(memoryCache)
                    
                    let diskCache = ImageManager.sharedManager().fetchDisk(url)
                    XCTAssertNotNil(diskCache)
                    
                    ImageManager.sharedManager().purgeMemory()
                    let nilMemoryCache = ImageManager.sharedManager().fetchMemory(url)
                    XCTAssertNil(nilMemoryCache)
                    
                    ImageManager.sharedManager().cleanDisk()
                    let nilDiskCache = ImageManager.sharedManager().fetchDisk(url)
                    XCTAssertNil(nilDiskCache)
                    
                    testExpectation.fulfill()
                }
            }
        }
        self.waitForExpectationsWithTimeout(30, handler: nil)
    }
    
    func testMemoryWarning() {

        let testKey = "testKey"
        ImageManager.sharedManager().write(testKey, image: image)
        
        XCTAssertNotNil(ImageManager.sharedManager().fetchMemory(testKey))
        
        NSNotificationCenter.defaultCenter().postNotificationName(UIApplicationDidReceiveMemoryWarningNotification, object: nil)
        
        XCTAssertNil(ImageManager.sharedManager().fetchMemory(testKey))
    }
    
    func testGaussianBlur() {
        let output = image?.blur(5)
        XCTAssertNotNil(output)
    }
    
    func testCornerRadius() {
        let output = image?.roundCorner(4)
        XCTAssertNotNil(output)
    }
    
    func testScale() {
        let output = image?.scaleToFill(CGSize(width: 100, height: 100))
        XCTAssertNotNil(output)
    }
    
    func testBatchOptions() {
        let expectation = self.expectationWithDescription("batch")
        Option.batch(image, options: [.GaussianBlur(5), .CornerRadius(8), .ScaleToFill(CGSize(width: 100, height: 100))]) { output in
            XCTAssertNotNil(output)
            expectation.fulfill()
        }
        self.waitForExpectationsWithTimeout(30, handler: nil)
    }
    
    func testImageView() {
        let expectation = self.expectationWithDescription("imageView")
        let imageView = UIImageView()
        imageView.sf_setImage(testUrl) { (image, error) in
            imageView.sf_setImage(self.testUrl)
            expectation.fulfill()
        }
        self.waitForExpectationsWithTimeout(30, handler: nil)
    }
    
    func testBatchDownload() {
        let expectation = self.expectationWithDescription("batch download")

        let imageUrls = [
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
            "http://image.tianjimedia.com/uploadImages/2012/159/RWS9KRJ03N1X_1000x500.jpg",
            ""
        ]
        
        ImageManager.sharedManager().downloadImages(imageUrls) { (images) in
            print(images)
            expectation.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(30, handler: nil)
    }
}

