//  StreamKit
//  Copyright © 2023 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

/// Output stream writing into a memory buffer.
public class DataOutputStream: OutputStream {
    public private(set) var data: Data
    
    public init() {
        self.data = Data()
    }
    
    public var hasSpaceAvailable: Bool { true }

    public func open() throws {
        data.removeAll(keepingCapacity: false)
    }
    
    public func close() throws {
        // nothing to do
    }
    
    public func write(_ buffer: UnsafePointer<UInt8>, count: Int) throws {
        data.append(buffer, count: count)
    }
}
