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
     Fetch image from cache.
     
     - parameter key:             Key.
     - parameter skipMemoryQuery: Search in memory first or not.
     
     - returns: Cached image or nil.
     */
    func fetch(key: String, skipMemoryQuery: Bool = false) -> UIImage? {
        return _cache.fetch(key, skipMemoryQuery: skipMemoryQuery)
    }
    
    /**
     Download image by url.
     
     - parameter url:  Image url.
     - parameter progress: Report downloading progress.
     - parameter done: Callback closure.
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
                        image = UIImage(data: d)
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