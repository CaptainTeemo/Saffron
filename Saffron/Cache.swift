//
//  Cache.swift
//  Saffron
//
//  Created by Captain Teemo on 3/29/16.
//  Copyright © 2016 Captain Teemo. All rights reserved.
//

import Foundation

internal func dispatchOnMain(_ closure: @escaping () -> Void) {
    if Thread.isMainThread {
        closure()
    } else {
        DispatchQueue.main.async(execute: closure)
    }
}

fileprivate let CachePrefix = "com.saffron.cache"

public final class Cache<Key: Hashable, Value> {
    fileprivate let cacheURL: URL
    fileprivate var cacheEntity = [Key:Value]()
    fileprivate let queue = DispatchQueue(label: CachePrefix)

    var dates = [Key:Date]()
    var semaphore = DispatchSemaphore(value: 1)
    var maxAge = TimeInterval.infinity
    
        /// Manual archive and unarchive should be used together.
    public var manualArchive: ((String, Value) -> Void)?
    public var manualUnarchive: ((String) -> Value?)?
    
    init(name: String = CachePrefix, cachePath: String = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0]) {
        cacheURL = URL(fileURLWithPath: cachePath + "/" + name)
        
        do {
            try createCacheDirectory()
        } catch let error {
            print(error)
        }
    }
    
    subscript (key: Key) -> Value? {
        get {
            lock()
            dates[key] = Date()
            let value = cacheEntity[key]
            unlock()
            if let v = value {
                return v
            } else {
                let path = self.path(for: key)
                var result: Value?
                if let manualUnarchive = manualUnarchive {
                    result = manualUnarchive(path)
                } else {
                    result = NSKeyedUnarchiver.unarchiveObject(withFile: path) as? Value
                }
                if let v = result {
                    lock()
                    cacheEntity[key] = v
                    unlock()
                }
                return result
            }
        }
        set {
            if let v = newValue {
                lock()
                dates[key] = Date()
                cacheEntity[key] = v
                unlock()
                
                let path = self.path(for: key)
                if let manualArchive = manualArchive {
                    manualArchive(path, v)
                } else {
                    let saved = NSKeyedArchiver.archiveRootObject(v, toFile: path)
                    if !saved {
                        print("\(path) save failed")
                    }
                }
            }
        }
    }
    
    func save(key: Key, value: Value, done: (() -> Void)?) {
        queue.async {
            self.dates[key] = Date()
            self[key] = value
            done?()
        }
    }
    
    func fetch(by key: Key, done: @escaping (Value?) -> Void) {
        queue.async {
            self.dates[key] = Date()
            let value = self[key]
            done(value)
        }
    }
    
    func lock() {
        semaphore.wait()
    }
    
    func unlock() {
        semaphore.signal()
    }
    
    func evictObject(for key: Key) {
        lock()
        cacheEntity.removeValue(forKey: key)
        unlock()
        
        queue.async {
            do {
                try FileManager.default.removeItem(atPath: self.path(for: key))
            } catch let error {
                print(error)
            }
        }
    }
    
    func trimCache(to date: Date) {
        lock()
        let currentDates = dates
        unlock()
        
        for (key, value) in currentDates {
            if value.compare(date) == .orderedAscending {
                evictObject(for: key)
            } else {
                break
            }
        }
    }
    
    func clearMemory() {
        lock()
        cacheEntity.removeAll()
        unlock()
    }
    
    func clearDisk() {
        queue.async {
            do {
                let items = try FileManager.default.contentsOfDirectory(at: self.cacheURL, includingPropertiesForKeys: nil, options: .skipsSubdirectoryDescendants)
                for item in items {
                    try FileManager.default.removeItem(at: item)
                }
            } catch let error {
                print(error)
            }
        }
    }
    
    func clear() {
        clearMemory()
        clearDisk()
    }
    
    fileprivate func path(for key: Key) -> String {
        let pathURL = URL(string: "\(key)")!
        let keyPath = pathURL.pathComponents.last!
        return cacheURL.appendingPathComponent(encode(key: keyPath)).path
    }
    
    fileprivate func createCacheDirectory() throws {
        if !FileManager.default.fileExists(atPath: cacheURL.path) {
            try FileManager.default.createDirectory(atPath: cacheURL.path, withIntermediateDirectories: false, attributes: nil)
        }
    }
    
    fileprivate func encode(key: String) -> String {
        if let encodedKey = key.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: ".:/%")) {
            return encodedKey
        }
        return ""
    }
    
    fileprivate func decode(key: String) -> String {
        return key.removingPercentEncoding ?? ""
    }
}
