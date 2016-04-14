//
//  Cache.swift
//  Saffron
//
//  Created by Captain Teemo on 3/29/16.
//  Copyright © 2016 Captain Teemo. All rights reserved.
//

import Foundation

internal func dispatchOnMain(closure: () -> Void) {
    if NSThread.isMainThread() {
        closure()
    } else {
        dispatch_async(dispatch_get_main_queue(), closure)
    }
}

private enum Constants {
    static let DefaultDiskCacheSize: Int64 = 10 << 20
    static let DefaultDiskCacheRecoreds: Int64 = 1000
    static let DefaultMemoryCacheRecordSize: Int64 = 1 << 20
    static let DiskCacheTimeResolution: NSTimeInterval = 1
    static let DiskCachePathKey = "path"
}

private class CacheEntry: NSObject {
    private var _value: Any?
    private var _creationTime: NSDate
    
    required init<T: DataConvertible>(value: T?, creationTime: NSDate = NSDate()) {
        _value = value
        _creationTime = creationTime
    }
}

/**
 *  Cache everything which conforms to protocol `DataConvertible`.
 */
public struct Cache<T: DataConvertible where T.Result == T> {
    
    // MARK: Properties
    
    private var _cacheDirectoryPath: String
    
    private let _diskCacheQueue = dispatch_queue_create("com.teemo.cache.disk", DISPATCH_QUEUE_SERIAL)
    private let _diskBarrierQueue = dispatch_queue_create("com.teemo.cache.disk.barrier", DISPATCH_QUEUE_CONCURRENT)
    private let _fileManager = NSFileManager.defaultManager()
    private let _memoryCache = NSCache()
    
    private var _lastDiskCacheModDate: NSDate?
    private var _lastDiskCacheSize: Int64 = 0
    private var _lastDiskCacheAttributes: [[String: AnyObject]]?
    
    private var dirtyCache: Bool {
        guard let date = _lastDiskCacheModDate else { return true }
        let modDate = modificationDate(_cacheDirectoryPath)
        let knownInterval = date.timeIntervalSinceReferenceDate
        let actualInterval = modDate.timeIntervalSinceReferenceDate
        
        return (actualInterval - knownInterval) >= Constants.DiskCacheTimeResolution
    }
    
        /// Size of disk cache.
    public var maxDiskCacheBytes = Constants.DefaultDiskCacheSize
        /// Amount of disk cache records.
    public var maxDiskCacheRecords = Constants.DefaultDiskCacheRecoreds
        /// Max cache size of each record for memory.
    public var maxMemoryCacheBytesPerRecord = Constants.DefaultMemoryCacheRecordSize
        /// How soon the cache will be expired.
    public var maxAge = NSTimeInterval.infinity
        /// Disk cache directory.
    public lazy var cacheDirectoryPath: String = {
        do {
            try self._fileManager.createDirectoryAtPath(self._cacheDirectoryPath, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            assertionFailure(error.localizedDescription)
        }
        return self._cacheDirectoryPath
    }()
    
    // MARK: Init with a cache path.
    
    public init(cacheDirectoryPath: String) {
        _cacheDirectoryPath = cacheDirectoryPath
    }
    
    // MARK: Public
    
    /**
     Write to cache, in memory and disk both.
     
     - parameter queryKey: Key.
     - parameter value:    Value
     - parameter done:     Callback closure.
     */
    public mutating func write(queryKey: String, value: T?, done: ((Bool) -> Void)? = nil) {
        let key = removeSlash(queryKey)
        
        let keyBytes = key.maximumLengthOfBytesUsingEncoding(key.fastestEncoding)
        let valueBytes = key.maximumLengthOfBytesUsingEncoding(key.fastestEncoding)
        
        if Int64(keyBytes + valueBytes) < maxMemoryCacheBytesPerRecord {
            _memoryCache.setObject(CacheEntry(value: value), forKey: key)
        } else {
            _memoryCache.removeObjectForKey(key)
        }
        
        dispatch_async(_diskCacheQueue) {
            let created = self.createDiskCacheEntry(value, path: self.cachePath(key))
            self.compact()
            
            dispatchOnMain({ 
                done?(created)
            })
        }
    }
    
    /**
     Fetch value from cache. First search in memory cache, if not hit then fetch from disk, or return nil.
     
     - parameter queryKey:   Key.
     - parameter fromMemory: Query from memory first or not.
     
     - returns: Cached value.
     */
    public func fetch(queryKey: String, skipMemoryQuery: Bool = false) -> T? {
        let key = removeSlash(queryKey)
        let cachePath = self.cachePath(key)
        
        if !skipMemoryQuery {
            if let cacheEntry = _memoryCache.objectForKey(key) as? CacheEntry {
                if NSDate().timeIntervalSinceDate(cacheEntry._creationTime) > maxAge {
                    evictObject(key)
                    return nil
                }
                
                dispatch_async(_diskCacheQueue, {
                    self.updateModificationDate(cachePath)
                })
                
                return cacheEntry._value as? T
            }
        }
        
        var value: T?
        
        dispatch_sync(_diskCacheQueue) {
            let modificationDate = self.modificationDate(cachePath)
            if NSDate().timeIntervalSinceDate(modificationDate) > self.maxAge {
                self.evictObject(key)
                return
            }
            
            value = self.fileContents(cachePath)
                        
            self._memoryCache.setObject(CacheEntry(value: value, creationTime: modificationDate), forKey: key)
        }
        
        return value
    }
    
    /**
     Remove cached value.
     
     - parameter key: Key.
     */
    public func evictObject(key: String) {
        _memoryCache.removeObjectForKey(key)
        dispatch_async(_diskCacheQueue) {
            do {
                try self._fileManager.removeItemAtPath(self.cachePath(key))
            } catch let error as NSError {
                debugPrint("\(#function): \(error)")
            }
        }
    }
    
    /**
     Clear all memory cache.
     */
    public func clearMemoryCache() {
        _memoryCache.removeAllObjects()
    }
    
    /**
     Clear all disk cache.
     */
    public func clearDiskCache() {
        dispatch_sync(_diskCacheQueue) {
            do {
                try self._fileManager.removeItemAtPath(self._cacheDirectoryPath)
            } catch let error as NSError {
                debugPrint("\(#function): \(error)")
            }
        }
    }
    
    // MARK: Private
    
    private func removeSlash(key: String) -> String {
        return key.stringByReplacingOccurrencesOfString("/", withString: "")
    }
    
    private func cachePath(key: String) -> String {
        return _cacheDirectoryPath + "/\(key)"
    }
    
    private func updateModificationDate(path: String) {
        do {
            try _fileManager.setAttributes([NSFileModificationDate: NSDate()], ofItemAtPath: path)
        } catch {}
    }
    
    private func modificationDate(path: String) -> NSDate {
        do {
            if let date = try _fileManager.attributesOfFileSystemForPath(path)[NSFileModificationDate] as? NSDate {
                return date
            }
        } catch {}
        
        return NSDate()
    }
    
    private mutating func invalidateDiskCache() {
        _lastDiskCacheModDate = nil
        _lastDiskCacheSize = 0
        _lastDiskCacheAttributes = nil
    }
    
    private func fileContents(path: String) -> T? {
        guard let data = _fileManager.contentsAtPath(path) else { return nil }
        updateModificationDate(path)
        return T.fromData(data)
    }
    
    private mutating func createDiskCacheEntry(value: T?, path: String) -> Bool {
        let bytes = value?.toData()
        let creationDate = NSDate()
        
        do {
            try _fileManager.createDirectoryAtPath(_cacheDirectoryPath, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            debugPrint("\(#function): \(error)")
        }
        
        let created = _fileManager.createFileAtPath(path, contents: bytes, attributes: [NSFileCreationDate: creationDate, NSFileModificationDate: creationDate])

        if !dirtyCache {
            _lastDiskCacheModDate = creationDate
            _lastDiskCacheSize += (bytes?.length ?? 0)
        } else {
            invalidateDiskCache()
        }
        
        return created
    }
    
    private mutating func rebuildCacheAttributes() {
        do {
            let cacheDirectoryAttributes = try _fileManager.attributesOfItemAtPath(_cacheDirectoryPath)
            
            _lastDiskCacheModDate = cacheDirectoryAttributes[NSFileModificationDate] as? NSDate
            _lastDiskCacheSize = 0
            _lastDiskCacheAttributes = [[String: AnyObject]]()
            
            if let enumerator = _fileManager.enumeratorAtPath(_cacheDirectoryPath) {
                while let path = enumerator.nextObject() as? String {
                    enumerator.skipDescendants()
                    
                    if let attributes = enumerator.fileAttributes,
                        let size = attributes[NSFileSize] as? NSNumber {
                        _lastDiskCacheSize += size.longLongValue
                        
                        let modDate = attributes[NSFileModificationDate] as! NSDate
                        
                        let entry: [String: AnyObject] = [Constants.DiskCachePathKey: path,
                                                          NSFileModificationDate: modDate,
                                                          NSFileSize: NSNumber(longLong: size.longLongValue)]
                        
                        if var lastAttributes = _lastDiskCacheAttributes {
                            let array = lastAttributes as NSArray
                            let insertionIndex = array.indexOfObject(entry, inSortedRange: NSMakeRange(0, lastAttributes.count), options: .InsertionIndex, usingComparator: { (value1, value2) -> NSComparisonResult in
                                let date1 = (value1 as! [String: AnyObject])[NSFileModificationDate] as! NSDate
                                let date2 = (value2 as! [String: AnyObject])[NSFileModificationDate] as! NSDate
                                return date1.compare(date2)
                            })
                            
                            lastAttributes.insert(entry, atIndex: insertionIndex)
                            _lastDiskCacheAttributes = lastAttributes
                        }
                    }
                }
            }
        } catch let error as NSError {
            debugPrint("\(#function): \(error)")
        }
    }
    
    private mutating func compact() {
        if dirtyCache {
            rebuildCacheAttributes()
        }
        
        guard var attributes = _lastDiskCacheAttributes else { return }
        while Int64(attributes.count) > maxDiskCacheRecords || _lastDiskCacheSize > maxDiskCacheBytes {
            dispatch_barrier_async(_diskBarrierQueue) {
                if let entry = attributes.first {
                    let toRemove = entry[Constants.DiskCachePathKey] as! String
                    let fileSize = entry[NSFileSize] as! NSNumber
                    do {
                        try self._fileManager.removeItemAtPath(self.cachePath(toRemove))
                    } catch let error as NSError {
                        debugPrint("\(#function): \(error)")
                    }
                    
                    self._lastDiskCacheSize -= fileSize.longLongValue
                    
                    attributes.removeFirst()
                    self._lastDiskCacheAttributes = attributes
                }
            }
        }
    }
}

// MARK: unit test
extension Cache {
    func fetchMemory(queryKey: String) -> T? {
        let key = removeSlash(queryKey)
        let cachePath = self.cachePath(key)
        
        if let cacheEntry = _memoryCache.objectForKey(key) as? CacheEntry {
            if NSDate().timeIntervalSinceDate(cacheEntry._creationTime) > maxAge {
                evictObject(key)
                return nil
            }
            
            dispatch_async(_diskCacheQueue, {
                self.updateModificationDate(cachePath)
            })
            
            return cacheEntry._value as? T
        }
        return nil
    }
    
    func fetchDisk(queryKey: String) -> T? {
        let key = removeSlash(queryKey)
        let cachePath = self.cachePath(key)
        
        var value: T?
        
        dispatch_sync(_diskCacheQueue) {
            let modificationDate = self.modificationDate(cachePath)
            if NSDate().timeIntervalSinceDate(modificationDate) > self.maxAge {
                self.evictObject(key)
                return
            }
            
            value = self.fileContents(cachePath)
            
            self._memoryCache.setObject(CacheEntry(value: value, creationTime: modificationDate), forKey: key)
        }
        
        return value
    }
    
    mutating func diskCacheRecordsCount() -> Int {
        let path = cacheDirectoryPath
        let contents = try? _fileManager.contentsOfDirectoryAtPath(path)
        return contents?.count ?? 0
    }
}