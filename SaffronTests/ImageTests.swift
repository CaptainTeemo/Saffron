//
//  ImageTests.swift
//  Saffron
//
//  Created by Captain Teemo on 4/8/16.
//  Copyright © 2016 Captain Teemo. All rights reserved.
//

import XCTest
import CoreGraphics
@testable import Saffron

class ImageTests: XCTestCase {
    let testUrl = URL(string: "http://screenrant.com/wp-content/uploads/Iron-Man-Robert-Downey-Jr-Interview.jpg")!
    
    lazy var image: UIImage = {
        let path = Bundle(for: type(of: self)).path(forResource: "Teemo", ofType: "jpg")
        let image = UIImage(contentsOfFile: path!)
        return image!
    }()
    
    lazy var imageData: Data? = {
        let path = Bundle(for: type(of: self)).path(forResource: "test", ofType: "gif")
        let data = try? Data(contentsOf: URL(fileURLWithPath: path!))
        return data
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
        let testExpectation = self.expectation(description: "downloadAndCache")
        let url = testUrl
        
        ImageManager.shared.downloadImage(url) { (image, error) in
            XCTAssertTrue(error == nil, "error: \(error)")
            if let image = image {
                ImageManager.shared.write(url.absoluteString, image: image) { () -> Void in
                    ImageManager.shared.fetch(url.absoluteString, done: { (image) in
                        XCTAssertNotNil(image)
                        ImageManager.shared.purgeMemory()
                        ImageManager.shared.fetch(url.absoluteString, done: { (image) in
                            XCTAssertNotNil(image)
                            ImageManager.shared.clearCache()
                            ImageManager.shared.fetch(url.absoluteString, done: { (image) in
                                XCTAssertNil(image)
                                testExpectation.fulfill()
                            })
                        })
                    })
                }
            }
        }
        self.waitForExpectations(timeout: 30, handler: nil)
    }
    
    func testMemoryWarning() {
        let testKey = "testKey"
        ImageManager.shared.write(testKey, image: image) { 
            ImageManager.shared.fetch(testKey, done: { (image) in
                XCTAssertNotNil(image)
                NotificationCenter.default.post(name: NSNotification.Name.UIApplicationDidReceiveMemoryWarning, object: nil)
                ImageManager.shared.fetch(testKey, done: { (image) in
                    XCTAssertNotNil(image)
                })
            })
        }
    }
    
    func testGaussianBlur() {
        let output = image.blur(with: 5)
        XCTAssertNotNil(output)
    }
    
    func testCornerRadius() {
        let output = image.roundCorner(4)
        XCTAssertNotNil(output)
    }
    
    func testScale() {
        let output = image.scaleToFill(CGSize(width: 100, height: 100))
        XCTAssertNotNil(output)
    }
    
    func testBatchOptions() {
        let expectation = self.expectation(description: "batch")
        Option.batch(image, options: [.gaussianBlur(5), .cornerRadius(8), .scaleToFill(CGSize(width: 100, height: 100))]) { output in
            XCTAssertNotNil(output)
            expectation.fulfill()
        }
        self.waitForExpectations(timeout: 30, handler: nil)
    }
    
    func testImageView() {
        let expectation = self.expectation(description: "imageView")
        let imageView = UIImageView()
        imageView.sf_setImage(testUrl) { (image, error) in
            imageView.sf_setImage(self.testUrl)
            expectation.fulfill()
        }
        self.waitForExpectations(timeout: 30, handler: nil)
    }
    
    func testAnimator() {
        let expectation = self.expectation(description: "imageView")
        let imageView = UIImageView()
        
        let animator = DefaultAnimator(animatorStyle: .none, revealStyle: .fade(0.6), reportProgress: false)
        imageView.sf_setAnimationLoader(animator)
        
        imageView.sf_setImage(testUrl) { (image, error) in
            imageView.sf_setImage(self.testUrl)
            expectation.fulfill()
        }
        self.waitForExpectations(timeout: 30, handler: nil)
    }
    
    func testBatchDownload() {
        let expectation = self.expectation(description: "batch download")

        let imageUrls = [
            URL(string: "http://image.tianjimedia.com/uploadImages/2012/159/2YUO85971OV7_1000x500.jpg")!,
            URL(string: "http://image.tianjimedia.com/uploadImages/2012/159/40S2O6S02ARH_1000x500.jpg")!
        ]
        
        ImageManager.shared.downloadImages(imageUrls) { (images) in
            print(images)
            expectation.fulfill()
        }
        
        self.waitForExpectations(timeout: 30, handler: nil)
    }
    
    func testDownloadRestpectCache() {
        let expectation = self.expectation(description: "cache download")

        ImageManager.shared.downloadImageRespectCache(testUrl) { (image, error) in
            print(image)
            print(error)
            ImageManager.shared.downloadImageRespectCache(self.testUrl, done: { (image, error) in
                expectation.fulfill()
            })
        }
        
        self.waitForExpectations(timeout: 30, handler: nil)
    }
    
    func testCacheQueryPolicy() {
        let expectation = self.expectation(description: "query policy")
        let imageView = UIImageView()
        imageView.sf_setImage(testUrl) { (image, error) in
            imageView.sf_setImage(self.testUrl, done: { (image, error) in
                expectation.fulfill()
            })
        }
        self.waitForExpectations(timeout: 30, handler: nil)
    }
    
    func testGifToVideo() {
        let expectation = self.expectation(description: "convert")
        if let data = imageData, let gif = UIImage.animatedGIF(data) {
            gif.gifData = data
            do {
                try GifToVideo.convert(gif, done: { path in
                    expectation.fulfill()
                })
            } catch {
                XCTAssert(false, "convert failed")
            }
        }
        self.waitForExpectations(timeout: 15, handler: nil)
    }
}

