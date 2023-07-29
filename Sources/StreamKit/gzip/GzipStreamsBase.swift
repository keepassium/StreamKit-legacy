//  StreamKit
//  Copyright © 2023 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation
import zlib

public typealias GzipCompressionLevel = Int32
public extension GzipCompressionLevel {
    static let noCompression = Z_NO_COMPRESSION
    static let bestSpeed = Z_BEST_SPEED
    static let bestCompression = Z_BEST_COMPRESSION
    static let defaultCompression = Z_DEFAULT_COMPRESSION
}

public struct GzipStreamError: LocalizedError {
    public enum ErrorKind: Equatable {
        case streamError
        case dataError
        case memoryError
        case bufferError
        case versionError
        case otherError(code: Int32)
    }
    
    public let kind: ErrorKind
    private let description: String?
    
    internal init(code: Int32, msg messagePointer: UnsafePointer<CChar>?) {
        if let messagePointer = messagePointer {
            description = String(cString: messagePointer, encoding: .utf8)
        } else {
            description = nil
        }
        
        switch code {
        case Z_STREAM_ERROR:  // -2
            kind = .streamError
        case Z_DATA_ERROR:    // -3
            kind = .dataError
        case Z_MEM_ERROR:     // -4
            kind = .memoryError
        case Z_BUF_ERROR:     // -5
            kind = .bufferError
        case Z_VERSION_ERROR: // -6
            kind = .versionError
        default:
            kind = .otherError(code: code)
        }
    }
    
    public var errorDescription: String? {
        switch kind {
        case .streamError,
             .dataError,
             .memoryError,
             .bufferError,
             .versionError:
            return description ?? "Unknown gzip error"
        case .otherError(let code):
            return description ?? "Unknown gzip error, code \(code)"
        }
    }
}
