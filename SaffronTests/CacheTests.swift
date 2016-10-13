//
//  CacheTests.swift
//  Saffron
//
//  Created by Captain Teemo on 4/8/16.
//  Copyright © 2016 Captain Teemo. All rights reserved.
//

import XCTest
@testable import Saffron

class CacheTests: XCTestCase {
    
    let stringKey = "cacheString"
    let imageKey = "cacheImage"
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testImageCache() {
        let path = Bundle(for: type(of: self)).path(forResource: "Teemo", ofType: "jpg")
        let image = UIImage(contentsOfFile: path!)
        
        let imageCache = Cache<String, UIImage>(name: "com.saffron.cache")
        
        let expectation = self.expectation(description: "writeImage")
        imageCache.save(key: imageKey, value: image!) { () -> Void in
            imageCache.fetch(by: self.imageKey, done: { (result) in
                XCTAssertNotNil(result)
                imageCache.clearMemory()
                imageCache.fetch(by: self.imageKey, done: { (result) in
                    XCTAssertNotNil(result)
                    imageCache.clear()
                    imageCache.fetch(by: self.imageKey, done: { (result) in
                        XCTAssertNil(result)
                        expectation.fulfill()
                    })
                })
            })
        }
    
        self.waitForExpectations(timeout: 30, handler: nil)
    }
    
    func testStringCache() {
        let expectation = self.expectation(description: "StringCache")
        
        let string = "test string"
        
        let stringCache = Cache<String, String>(name: "com.saffron.cache")
        stringCache.save(key: stringKey, value: string) { () -> Void in
            stringCache.save(key: self.stringKey, value: string) { () -> Void in
                stringCache.fetch(by: self.stringKey, done: { (result) in
                    XCTAssertNotNil(result)
                    stringCache.clearMemory()
                    stringCache.fetch(by: self.stringKey, done: { (result) in
                        XCTAssertNotNil(result)
                        stringCache.clear()
                        stringCache.fetch(by: self.stringKey, done: { (result) in
                            XCTAssertNil(result)
                            expectation.fulfill()
                        })
                    })
                })
            }
        }
        
        self.waitForExpectations(timeout: 3, handler: nil)
    }
    
    func testCacheAgeControl() {
        let path = Bundle(for: type(of: self)).path(forResource: "Teemo", ofType: "jpg")
        let image = UIImage(contentsOfFile: path!)
        
        let imageCache = Cache<String, UIImage>(name: "com.saffron.cache")
        imageCache.maxAge = 3
        
        let expectation = self.expectation(description: "writeImage")
        
        let delay = DispatchTime.now() + Double(Int64(4 * NSEC_PER_SEC)) / Double(NSEC_PER_SEC)
        
        imageCache.save(key: imageKey, value: image!) {
            DispatchQueue.main.asyncAfter(deadline: delay) {
                imageCache.fetch(by: self.imageKey, done: { (image) in
                    XCTAssertNil(image)
                })
                expectation.fulfill()
            }
        }
        
        self.waitForExpectations(timeout: 5, handler: nil)
    }
    
//    func testDiskCacheSizeControl() {
//        let maxRecords = 10
//        
//        let expectation = self.expectation(description: "cache")
//        
//        var cache = Cache<String, String>(cacheDirectoryPath: ImageManager.cachePath)
//        cache.maxDiskCacheRecords = Int64(maxRecords)
//        
//        let group = DispatchGroup()
//        for i in 0...maxRecords {
//            group.enter()
//            cache.write("\(i)", value: "\(i)", done: { (finished) in
//                XCTAssertTrue(finished)
//                group.leave()
//            })
//        }
//        
//        group.notify(queue: DispatchQueue.main) { 
//            expectation.fulfill()
//            assert(cache.diskCacheRecordsCount() <= maxRecords)
//        }
//        
//        self.waitForExpectations(timeout: 15, handler: nil)
//    }
    
}
