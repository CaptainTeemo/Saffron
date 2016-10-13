//
//  Error.swift
//  Saffron
//
//  Created by CaptainTeemo on 7/18/16.
//  Copyright © 2016 Captain Teemo. All rights reserved.
//

import Foundation

internal struct Error {
    static let errorDomain = "com.saffron.error"
    static func error(_ code: Int, description: String) -> NSError {
        return NSError(domain: errorDomain, code: code, userInfo: [NSLocalizedDescriptionKey: description])
    }
}
