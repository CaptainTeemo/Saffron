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
    
    let testUrl = "http://screenrant.com/wp-content/uploads/Iron-Man-Robert-Downey-Jr-Interview.jpg"
    
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
    
    func testAnimator() {
        let expectation = self.expectationWithDescription("imageView")
        let imageView = UIImageView()
        
        let animator = DefaultAnimator(animatorStyle: .None, revealStyle: .Fade(0.6), reportProgress: false)
        imageView.sf_setAnimationLoader(animator)
        
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
            ""
        ]
        
        ImageManager.sharedManager().downloadImages(imageUrls) { (images) in
            print(images)
            expectation.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(30, handler: nil)
    }
    
    func testDownloadRestpectCache() {
        let expectation = self.expectationWithDescription("cache download")

        ImageManager.sharedManager().downloadImageRespectCache(testUrl) { (image, error) in
            print(image)
            print(error)
            ImageManager.sharedManager().downloadImageRespectCache(self.testUrl, done: { (image, error) in
                expectation.fulfill()
            })
        }
        
        self.waitForExpectationsWithTimeout(30, handler: nil)
    }
    
    func testCacheQueryPolicy() {
        let expectation = self.expectationWithDescription("query policy")
        let imageView = UIImageView()
        imageView.sf_setImage(testUrl) { (image, error) in
            imageView.sf_setImage(self.testUrl, queryPolicy: .IgnoreAllCache, done: { (image, error) in
                expectation.fulfill()
            })
        }
        self.waitForExpectationsWithTimeout(30, handler: nil)
    }
}

