//
//  ThreadHelper.swift
//  Saffron
//
//  Created by CaptainTeemo on 11/2/16.
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
