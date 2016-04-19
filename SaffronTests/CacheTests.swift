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
        let path = NSBundle(forClass: self.dynamicType).pathForResource("Teemo", ofType: "jpg")
        let image = UIImage(contentsOfFile: path!)
        
        var imageCache = Cache<UIImage>(cacheDirectoryPath: ImageManager.cachePath)
        
        let expectation = self.expectationWithDescription("writeImage")
        imageCache.write(imageKey, value: image) { (finished) -> Void in
            
            XCTAssertTrue(finished)
            
            let memoryCache = imageCache.fetchMemory(self.imageKey)
            XCTAssertNotNil(memoryCache)
            
            let diskCache = imageCache.fetchDisk(self.imageKey)
            XCTAssertNotNil(diskCache)
            
            imageCache.clearMemoryCache()
            let nilMemoryCache = imageCache.fetchMemory(self.imageKey)
            XCTAssertNil(nilMemoryCache)
            
            imageCache.clearDiskCache()
            let nilDiskCache = imageCache.fetchDisk(self.imageKey)
            XCTAssertNil(nilDiskCache)
            
            expectation.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(30, handler: nil)
    }
    
    func testStringCache() {
        let string = "test string"
        
        var stringCache = Cache<String>(cacheDirectoryPath: ImageManager.cachePath)
        
        let expectation = self.expectationWithDescription("writeString")
        stringCache.write(stringKey, value: string) { (finished) -> Void in
            
            XCTAssertTrue(finished)
            
            let memoryCache = stringCache.fetchMemory(self.stringKey)
            XCTAssertNotNil(memoryCache)
            
            let diskCache = stringCache.fetchDisk(self.stringKey)
            XCTAssertNotNil(diskCache)
            
            stringCache.clearMemoryCache()
            let nilMemoryCache = stringCache.fetchMemory(self.stringKey)
            XCTAssertNil(nilMemoryCache)
            
            stringCache.clearDiskCache()
            let nilDiskCache = stringCache.fetchDisk(self.stringKey)
            XCTAssertNil(nilDiskCache)
            
            expectation.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(3, handler: nil)
    }
    
    func testCacheAgeControl() {
        let path = NSBundle(forClass: self.dynamicType).pathForResource("Teemo", ofType: "jpg")
        let image = UIImage(contentsOfFile: path!)
        
        var imageCache = Cache<UIImage>(cacheDirectoryPath: ImageManager.cachePath)
        imageCache.maxAge = 3
        
        let expectation = self.expectationWithDescription("writeImage")
        
        let delay = dispatch_time(DISPATCH_TIME_NOW, Int64(4 * NSEC_PER_SEC))
        
        imageCache.write(imageKey, value: image) { (finished) -> Void in
            
            XCTAssertTrue(finished)
            
            dispatch_after(delay, dispatch_get_main_queue(), { 
                let memoryCache = imageCache.fetchMemory(self.imageKey)
                XCTAssertNil(memoryCache)
                
                let diskCache = imageCache.fetchDisk(self.imageKey)
                XCTAssertNil(diskCache)
                
                expectation.fulfill()
            })
        }
        
        self.waitForExpectationsWithTimeout(5, handler: nil)
    }
    
    func testDiskCacheSizeControl() {
        let maxRecords = 10
        
        let expectation = self.expectationWithDescription("cache")
        
        var cache = Cache<String>(cacheDirectoryPath: ImageManager.cachePath)
        cache.maxDiskCacheRecords = Int64(maxRecords)
        
        let group = dispatch_group_create()
        for i in 0...maxRecords {
            dispatch_group_enter(group)
            cache.write("\(i)", value: "\(i)", done: { (finished) in
                XCTAssertTrue(finished)
                dispatch_group_leave(group)
            })
        }
        
        dispatch_group_notify(group, dispatch_get_main_queue()) { 
            expectation.fulfill()
            assert(cache.diskCacheRecordsCount() <= maxRecords)
        }
        
        self.waitForExpectationsWithTimeout(15, handler: nil)
    }
}
