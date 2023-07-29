//  StreamKit
//  Copyright © 2023 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public protocol OutputStream {
    var hasSpaceAvailable: Bool { get }
    
    func open() throws
    
    /// Writes `count` bytes from `buffer` into the stream.
    func write(_ buffer: UnsafePointer<UInt8>, count: Int) throws
    
    func close() throws
}

