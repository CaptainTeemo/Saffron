//
//  ImageManager.swift
//  Saffron
//
//  Created by Captain Teemo on 3/29/16.
//  Copyright © 2016 Captain Teemo. All rights reserved.
//

import Foundation

fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l < r
    case (nil, _?):
        return true
    default:
        return false
    }
}

fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l > r
    default:
        return rhs < lhs
    }
}


private let ErrorDomain = "SaffronErrorDomain"

/// Handle image download and cache stuff.
public final class ImageManager {
        /// Singleton access.
    public static let shared = ImageManager()
    
    fileprivate var _cache = Cache<String, UIImage>(name: "com.saffron.imagecache")
    fileprivate let _queue = OperationQueue()
    
        /// How soon the image cache will be expired.
    open var maxCacheAge = TimeInterval.infinity {
        willSet {
            _cache.maxAge = newValue
        }
    }
    
    fileprivate init() {
        // since NSCache will be automatically purged when receiving memory warning, we might not need it anymore.
        NotificationCenter.default.addObserver(forName: NSNotification.Name.UIApplicationDidReceiveMemoryWarning, object: nil, queue: nil) { (notification) in
            self.purgeMemory()
        }
        
        _cache.manualArchive = { path, image in
            let saved = FileManager.default.createFile(atPath: path, contents: image.sf_isGIF ? image.gifData : UIImagePNGRepresentation(image), attributes: nil)
            if !saved {
                print("save failed")
            }
        }
        
        _cache.manualUnarchive = { path in
            if let data = FileManager.default.contents(atPath: path) {
                return UIImage.animatedGIF(data)
            }
            return nil
        }
    }
    
    /**
     Write image to cache.
     
     - parameter key:   Key.
     - parameter image: Value.
     - parameter done:  Callback.
     */
    public func write(_ key: String, image: UIImage, done: (() -> Void)? = nil) {
        _cache.save(key: key, value: image, done: done)
    }
    
    /**
     Fetch image from cache asynchronously.
     
     - parameter key:             Key.
     - parameter queryPolicy:     Query policy, see `CacheQueryPolicy`.
     - parameter done:            Callback when done in main thread.
     */
    public func fetch(_ key: String, done: @escaping (UIImage?) -> Void) {
        _cache.fetch(by: key) { (image) in
            var cachedImage = image
            if let image = image, !image.sf_isGIF {
                cachedImage = UIImage.decodeImage(image)
            }
            dispatchOnMain {
                done(cachedImage)
            }
        }
//        _cache.fetch(key, queryPolicy: queryPolicy) { (image) in
//            self._queue.addOperation({ 
//                var cachedImage = image
//                if image?.gifData == nil {
//                    cachedImage = UIImage.decodeImage(image)
//                }
//                dispatchOnMain({
//                    done(cachedImage)
//                })
//            })
//
//        }
    }
    
    /**
     Download image by url.
     
     - parameter url:  Image url.
     - parameter progress: Report downloading progress.
     - parameter progressiveImage: Fetch current progressive image.
     - parameter done: Callback when done in main thread.
     */
    @discardableResult public func downloadImage(_ url: URL, progress: ((Int64, Int64) -> Void)? = nil, progressiveImage: ((UIImage) -> Void)? = nil, done: @escaping (UIImage?, NSError?) -> Void) -> Operation {
        let downloadOperation = DownloadOperation(url: url, queue: _queue)
        downloadOperation.progress = progress
        downloadOperation.progressiveClosure = progressiveImage
        downloadOperation.completionBlock = { () -> Void in
            var image: UIImage?
            var error: NSError?
            if downloadOperation.isFinished {
                if let data = downloadOperation.data {
                    if let range = url.absoluteString.range(of: ".gif"), !range.isEmpty {
                        image = UIImage.animatedGIF(data)
                        image?.gifData = data
                    } else {
                        image = UIImage.decodeImage(UIImage(data: data))
                    }
                } else {
                    error = NSError(domain: ErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: "Donwload failed"])
                }
            }
            
            if downloadOperation.isCancelled {
                error = NSError(domain: ErrorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: "Donwload cancelled"])
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
    public func downloadImages(_ urls: [URL], done: @escaping ([UIImage?]) -> Void) {
        var images = [UIImage?]()
        let group = DispatchGroup()
        
        for url in urls {
            group.enter()
            self._cache.fetch(by: url.absoluteString, done: { (image) in
                guard image == nil else { group.leave(); return }
                self.downloadImage(url, done: { (image, error) in
                    if let downloadedImage = image {
                        self._cache.save(key: url.absoluteString, value: downloadedImage, done: { 
                            group.leave()
                        })
                    }
                })
            })
        }
        
        group.notify(queue: DispatchQueue.main) { 
            for url in urls {
                self._cache.fetch(by: url.absoluteString, done: { (image) in
                    images.append(image)
                    if images.count == urls.count {
                        done(images)
                    }
                })
            }
        }
    }
    
    /**
     Download image but first look up in cache.
     
     - parameter url:  Key.
     - parameter done: Callback when done in main thread.
     */
    public func downloadImageRespectCache(_ url: URL, task: ((Operation) -> Void)? = nil, progress: ((Int64, Int64) -> Void)? = nil, done: @escaping (UIImage?, NSError?) -> Void) {
        _cache.fetch(by: url.absoluteString) { (image) in
            if let cachedImage = image {
                dispatchOnMain({
                    done(cachedImage, nil)
                })
            } else {
                let operation = self.downloadImage(url, progress: progress, done: { (downloadedImage, error) in
                    guard let d = downloadedImage else { done(nil, error); return }
                    self._cache.save(key: url.absoluteString, value: d, done: { (finished) in
                        dispatchOnMain({
                            done(d, error)
                        })
                    })
                })
                task?(operation)
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
        _cache.clearMemory()
    }
    
    /**
     Clear disk cache.
     */
    public func cleanDisk() {
        _cache.clearDisk()
    }
    
    /**
     Clear memory and disk cache.
     */
    public func clearCache() {
        _cache.clear()
    }
}

// MARK: Download Operation
private class DownloadOperation: Operation {
    fileprivate var _url: URL
    fileprivate var _queue: OperationQueue
    fileprivate var _task: URLSessionTask?
    fileprivate var _totalBytes: Int64 = 0
    fileprivate var _mutableData = Data()
    fileprivate var _progressiveImage: ProgressiveImage?
    
    fileprivate var _finished = false
    override var isFinished: Bool {
        set {
            self.willChangeValue(forKey: "isFinished")
            _finished = newValue
            self.didChangeValue(forKey: "isFinished")
        }
        get {
            return _finished
        }
    }
    
    var data: Data?
    var progress: ((Int64, Int64) -> Void)?
    var progressiveClosure: ((UIImage) -> Void)?
    
    init(url: URL, queue: OperationQueue) {
        _url = url
        _queue = queue
    }
    
    override func start() {
        if isCancelled {
            return
        }
        
        let config = URLSessionConfiguration.default
        let session = Foundation.URLSession(configuration: config, delegate: self, delegateQueue: self._queue)
        let request = URLRequest(url: _url, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 15)
        let task = session.dataTask(with: request)
        task.resume()
        
        _task = task
    }
    
    override func cancel() {
        _task?.cancel()
        super.cancel()
    }
}

extension DownloadOperation: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        _totalBytes = response.expectedContentLength
        
        completionHandler(_totalBytes > 0 ? .allow : .cancel)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if isCancelled {
            isFinished = true
            self.data = nil
            return
        }
        
//        data.enumerateBytes { (bytes, range, stop) in
//            self._mutableData.append(Data(bytes: UnsafeBufferPointer<UInt8>(bytes), count: range.length))
//        }
        
        _mutableData.append(data)
        
        progress?(Int64(_mutableData.count), _totalBytes)
        
        if progressiveClosure != nil {
            if _progressiveImage == nil {
                _progressiveImage = ProgressiveImage()
            }
            _progressiveImage?.updateProgressiveImage(data, expectedNumberOfBytes: _totalBytes)
            if let image = _progressiveImage?.currentImage(true, quality: 1) {
                progressiveClosure?(image)
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Swift.Error?) {
        data = _mutableData as Data
        if Int64(_mutableData.count) != _totalBytes {
            data = nil
        }
        isFinished = true
    }
}
