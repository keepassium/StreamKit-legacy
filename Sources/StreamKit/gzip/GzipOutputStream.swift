//  StreamKit
//  Copyright © 2023 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation
import zlib

/// Compresses incoming data using zlib, writes the compressed output to an underlying stream.
public final class GzipOutputStream: OutputStream {
    public static let defaultChunkSize = 1 << 16
    
    private let outStream: OutputStream
    private let level: GzipCompressionLevel
    private let chunkSize: Int
    private var zStream: z_stream
    private var status: Int32
    private var outBuffer: UnsafeMutablePointer<Bytef>
    private var wasOpened = false
    
    public init(
        writingTo outStream: OutputStream,
        level: GzipCompressionLevel = .defaultCompression,
        chunkSize: Int = GzipOutputStream.defaultChunkSize
    ) {
        self.outStream = outStream
        self.chunkSize = chunkSize
        self.level = level
        self.zStream = z_stream()
        self.status = Z_OK
        self.outBuffer = .allocate(capacity: chunkSize)
    }
    
    deinit {
        outBuffer.deallocate()
    }
    
    public var hasSpaceAvailable: Bool {
        return outStream.hasSpaceAvailable
    }
    
    public func open() throws {
        if wasOpened {
            fatalError("An instance of GzipOutputStream can be opened only once.")
        }
        wasOpened = true

        let zStreamSize = MemoryLayout<z_stream>.size
        status = deflateInit2_(
            &zStream,
            level,
            Z_DEFLATED,
            MAX_WBITS + 16,
            MAX_MEM_LEVEL,
            Z_DEFAULT_STRATEGY,
            ZLIB_VERSION,
            Int32(zStreamSize)
        )
        
        guard status == Z_OK else {
            throw GzipStreamError(code: status, msg: zStream.msg)
        }
    }
    
    /// Compresses `count` bytes from `buffer` into the stream.
    public func write(_ buffer: UnsafePointer<UInt8>, count: Int) throws {
        zStream.next_in = UnsafeMutablePointer(mutating: buffer)
        zStream.avail_in = uInt(count)
        do {
            while zStream.avail_in > 0 {
                repeat {
                    zStream.next_out = outBuffer
                    zStream.avail_out = uInt(chunkSize)
                    status = deflate(&zStream, Z_NO_FLUSH)
                    guard status != Z_STREAM_ERROR else {
                        throw GzipStreamError(code: status, msg: zStream.msg)
                    }
                    let outBytesCount = chunkSize - Int(zStream.avail_out)
                    try outStream.write(outBuffer, count: outBytesCount)
                } while zStream.avail_out == 0
            }
        } catch {
            deflateEnd(&zStream)
            throw error
        }
    }
    
    /// Finishes processing the data and closes the stream.
    /// _WARNING:_ Until this method is called, the output is not complete!
    public func close() throws {
        assert(wasOpened, "Tried to close a stream that was never opened.")
        
        zStream.next_in = nil
        zStream.avail_in = 0
        do {
            repeat {
                zStream.next_out = outBuffer
                zStream.avail_out = uInt(chunkSize)
                status = deflate(&zStream, Z_FINISH)
                guard status != Z_STREAM_ERROR else {
                    throw GzipStreamError(code: status, msg: zStream.msg)
                }
                let outBytesCount = chunkSize - Int(zStream.avail_out)
                try outStream.write(outBuffer, count: outBytesCount)
            } while status != Z_STREAM_END
        } catch {
            deflateEnd(&zStream)
            throw error
        }
    }
}
