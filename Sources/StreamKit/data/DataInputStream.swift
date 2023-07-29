//  StreamKit
//  Copyright © 2023 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

/// Input stream reading from a memory buffer.
public class DataInputStream: InputStream {
    private let data: Data
    private var position: Int
    
    public init(from data: Data) {
        self.data = data
        self.position = 0
    }
    
    public var hasDataAvailable: Bool {
        return position < data.count
    }

    public func open() throws {
        position = 0
        // nothing else
    }
    
    public func close() {
        position = data.count
        // nothing else
    }

    public func read(_ buffer: UnsafeMutablePointer<UInt8>, maxCount: Int) throws -> Int {
        let bytesLeft = data.count - position
        let bytesToRead = min(maxCount, bytesLeft)
        _ = data.withUnsafeBytes {
            memcpy(buffer, $0.baseAddress?.advanced(by: position), bytesToRead)
        }
        position += bytesToRead
        return bytesToRead
    }
}
