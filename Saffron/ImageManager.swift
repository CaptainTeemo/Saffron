//
//  ImageManager.swift
//  Saffron
//
//  Created by Captain Teemo on 3/29/16.
//  Copyright © 2016 Captain Teemo. All rights reserved.
//

import Foundation

private let ErrorDomain = "SaffronErrorDomain"

/// Handle image download and cache stuff.
public class ImageManager {
    private static let _sharedManager = ImageManager()
    private var _cache = Cache<UIImage>(cacheDirectoryPath: ImageManager.cachePath)
    private let _queue = NSOperationQueue()
    
        /// How soon the image cache will be expired.
    public var maxCacheAge = NSTimeInterval.infinity {
        willSet {
            _cache.maxAge = newValue
        }
    }
    
        /// Path of image cache.
    public static var cachePath: String {
        let cachesPath = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.CachesDirectory, NSSearchPathDomainMask.UserDomainMask, true)[0]
        return cachesPath + "/com.saffron.imagecache"
    }
    
    /**
     Singleton access.
     
     - returns: Instance of ImageManager
     */
    public class func sharedManager() -> ImageManager {
        return _sharedManager
    }
    
    private init() {
        // since NSCache will be automatically purged when receiving memory warning, we might not need it anymore.
        NSNotificationCenter.defaultCenter().addObserverForName(UIApplicationDidReceiveMemoryWarningNotification, object: nil, queue: nil) { (notification) in
            self.purgeMemory()
        }
    }
    
    /**
     Write image to cache.
     
     - parameter key:   Key.
     - parameter image: Value.
     - parameter done:  Callback.
     */
    func write(key: String, image: UIImage?, done: ((Bool) -> Void)? = nil) {
        _cache.write(key, value: image, done: done)
    }
    
    /**
     Fetch image from cache asynchronously.
     
     - parameter key:             Key.
     - parameter skipMemoryQuery: Search in memory first or not.
     - parameter done:            Callback when done in main thread.
     */
    func fetch(key: String, skipMemoryQuery: Bool = false, done: (UIImage?) -> Void) {
        _cache.fetch(key, skipMemoryQuery: skipMemoryQuery) { (image) in
            self._queue.addOperationWithBlock({ 
                var cachedImage = image
                if image?.gifData == nil {
                    cachedImage = UIImage.decodeImage(image)
                }
                dispatchOnMain({
                    done(cachedImage)
                })
            })

        }
    }
    
    /**
     Download image by url.
     
     - parameter url:  Image url.
     - parameter progress: Report downloading progress.
     - parameter done: Callback when done in main thread.
     */
    public func downloadImage(url: String, progress: ((Int64, Int64) -> Void)? = nil, done: (UIImage?, NSError?) -> Void) -> NSOperation {
        let downloadOperation = DownloadOperation(url: url, queue: _queue)
        downloadOperation.progress = progress
        downloadOperation.completionBlock = { () -> Void in
            var image: UIImage?
            var error: NSError?
            if downloadOperation.finished {
                if let d = downloadOperation.data {
                    if url.rangeOfString(".gif")?.count > 0 {
                        image = UIImage.animatedGIF(d)
                        image?.gifData = d
                    } else {
                        image = UIImage.decodeImage(UIImage(data: d))
                    }
                } else {
                    error = NSError(domain: ErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: "Donwload failed"])
                }
            }
            
            dispatchOnMain({ 
                done(image, error)
            })
        }
        
        _queue.addOperation(downloadOperation)
        
        return downloadOperation
    }
    
    /**
     Batch download images.
     
     - parameter urls:     Array of url.
     - parameter done:     Compeletion handler in main thread.
     */
    public func downloadImages(urls: [String], done: ([UIImage?]) -> Void) {
        var images = [UIImage?]()
        let group = dispatch_group_create()
        for url in urls {
            dispatch_group_enter(group)
            downloadImage(url, done: { (image, error) in
                self._cache.write(url, value: image, done: { (finished) in
                    dispatch_group_leave(group)
                })
            })
        }
        
        dispatch_group_notify(group, dispatch_get_main_queue()) { 
            for url in urls {
                self._cache.fetch(url, done: { (image) in
                    images.append(image)
                    if images.count == urls.count {
                        done(images)
                    }
                })
            }
        }
    }
    
    /**
     Cancel downoading operations.
     */
    public func cancelAllOperations() {
        _queue.cancelAllOperations()
    }
    
    /**
     Clear memory cache.
     */
    public func purgeMemory() {
        _cache.clearMemoryCache()
    }
    
    /**
     Clear disk cache.
     */
    public func cleanDisk() {
        _cache.clearDiskCache()
    }
    
    /**
     Clear memory and disk cache.
     */
    public func clearCache() {
        _cache.clearMemoryCache()
        _cache.clearDiskCache()
    }
}

// MARK: Download Operation
private class DownloadOperation: NSOperation {
    
    private var _url: String
    private var _queue: NSOperationQueue
    private var _task: NSURLSessionTask?
    
    private var _finished = false
    override var finished: Bool {
        set {
            self.willChangeValueForKey("isFinished")
            _finished = newValue
            self.didChangeValueForKey("isFinished")
        }
        get {
            return _finished
        }
    }
    
    var data: NSData?
    var progress: ((Int64, Int64) -> Void)?
    
    init(url: String, queue: NSOperationQueue) {
        _url = url
        _queue = queue
    }
    
    override func start() {
        if cancelled {
            return
        }
        
        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
        let session = NSURLSession(configuration: config, delegate: self, delegateQueue: self._queue)
        let task = session.downloadTaskWithURL(NSURL(string: _url)!)
        task.resume()
        
        _task = task
    }
    
    override func cancel() {
        _task?.cancel()
        super.cancel()
    }
}

extension DownloadOperation: NSURLSessionDownloadDelegate {
    @objc func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL location: NSURL) {
        
        if cancelled {
            return
        }
        
        let data = NSData(contentsOfURL: location)
        self.data = data
        
        finished = true
    }
    
    @objc func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        progress?(totalBytesWritten, totalBytesExpectedToWrite)
    }
}

// MARK: unit test
extension ImageManager {
    func fetchMemory(key: String) -> UIImage? {
        return _cache.fetchMemory(key)
    }
    
    func fetchDisk(key: String) -> UIImage? {
        return _cache.fetchDisk(key)
    }
}