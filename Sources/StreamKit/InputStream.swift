//  StreamKit
//  Copyright © 2023 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public protocol InputStream {
    var hasDataAvailable: Bool { get }
    
    func open() throws
    
    /// Reads up to `maxCount` bytes from the stream into `buffer`.
    /// Returns the number of bytes actually read.
    func read(_ buffer: UnsafeMutablePointer<UInt8>, maxCount: Int) throws -> Int
    
    func close()
}
