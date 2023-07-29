//  StreamKit
//  Copyright © 2023 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation
import zlib

/// Takes in compressed Gzip data, outputs decompressed data.
public final class GzipInputStream: InputStream {

    public static let defaultInChunkSize  = 1 << 14
    public static let defaultOutChunkSize = 1 << 16
    
    private let compressedStream: InputStream
    private let windowBits: Int32
    private let inChunkSize: Int
    private let outChunkSize: Int
    
    private var zStream: z_stream
    private var status: Int32
    private var compressedBuffer: UnsafeMutablePointer<Bytef>
    private var isEndOfInput: Bool
    private var decompressedBuffer: UnsafeMutablePointer<Bytef>
    private var decompressedBytesRemaining: Int
    private var decompressedBufferOffset: Int
    private var wasOpened = false
    
    public init(
        readingFrom inputStream: InputStream,
        windowBits: Int32 = MAX_WBITS + 15,
        inChunkSize: Int = GzipInputStream.defaultInChunkSize,
        outChunkSize: Int = GzipInputStream.defaultOutChunkSize
    ) {
        self.compressedStream = inputStream
        self.windowBits = windowBits
        self.inChunkSize = inChunkSize
        self.outChunkSize = outChunkSize
        
        self.zStream = z_stream()
        self.status = Z_OK
        self.compressedBuffer = .allocate(capacity: inChunkSize)
        self.isEndOfInput = false
        self.decompressedBuffer = .allocate(capacity: outChunkSize)
        self.decompressedBufferOffset = 0
        self.decompressedBytesRemaining = 0
    }
    
    deinit {
        compressedBuffer.deallocate()
        decompressedBuffer.deallocate()
    }

    public var hasDataAvailable: Bool {
        let isDone = isEndOfInput && decompressedBytesRemaining == 0
        return !isDone
    }
    
    /// Prepares the stream for decompression.
    /// Note: can be called only once for the stream instance.
    public func open() throws {
        if wasOpened {
            fatalError("An instance of GzipInputStream can be opened only once.")
        }
        wasOpened = true

        let zStreamSize = MemoryLayout<z_stream>.size
        status = inflateInit2_(&zStream, windowBits, ZLIB_VERSION, Int32(zStreamSize))
        guard status == Z_OK else {
            throw GzipStreamError(code: status, msg: zStream.msg)
        }
        zStream.next_in = nil
        zStream.avail_in = 0
        zStream.next_out = nil
        zStream.avail_out = 0
    }
    
    /// Reads up to `maxCount` bytes into `buffer`, decompressing them
    /// from the underlying stream.
    /// Returns the number of bytes actually produced.
    public func read(_ buffer: UnsafeMutablePointer<UInt8>, maxCount: Int) throws -> Int {
        // Terminology:
        // - compressedBuffer - contains data from the compressed stream (size: 0..<inChunkSize)
        // - decompressedBuffer - inflated from the compressedBuffer (size: 0..<outChunkSize)
        // - outBuffer - user's buffer (size: maxLength) we are copying to from decompressedBuffer
        var outBytesRemaining = maxCount
        var outBufferOffset = 0
        while outBytesRemaining > 0 {
            if decompressedBytesRemaining == 0 {
                decompressedBytesRemaining = try fillOutDecompressedBuffer()
                decompressedBufferOffset = 0
                guard decompressedBytesRemaining > 0 else {
                    if isEndOfInput { // all good
                        return outBufferOffset
                    } else {
                        throw GzipStreamError(code: status, msg: zStream.msg)
                    }
                }
            } else if decompressedBytesRemaining > 0 {
                // no need to decompress, finish the remaining decompressed bytes
                let decompressedStart = decompressedBuffer + decompressedBufferOffset
                let bytesToCopy = min(decompressedBytesRemaining, outBytesRemaining)
                (buffer + outBufferOffset).initialize(from: decompressedStart, count: bytesToCopy)
                decompressedBufferOffset += bytesToCopy
                decompressedBytesRemaining -= bytesToCopy
                outBytesRemaining -= bytesToCopy
                outBufferOffset += bytesToCopy
            } else {
                fatalError("decompressedBytesRemaining is negative?!")
            }
        }
        return outBufferOffset
    }
    
    /// Tries to fill out the `decompressedBuffer` (fully and from its beginning)
    /// with decompressed data, reading the `compressedStream` when necessary.
    /// Returns the number of bytes actually produced.
    private func fillOutDecompressedBuffer() throws -> Int {
        if isEndOfInput {
            return 0
        }
        decompressedBufferOffset = 0
        zStream.next_out = decompressedBuffer
        zStream.avail_out = uInt(outChunkSize)
        repeat {
            if zStream.avail_in == 0 { // need more input
                let compressedBytesCount = try compressedStream.read(compressedBuffer, maxCount: inChunkSize)
                if compressedBytesCount == 0 {
                    let producedByteCount = outChunkSize - Int(zStream.avail_out)
                    isEndOfInput = true
                    try finalize()
                    return producedByteCount
                }
                zStream.next_in = compressedBuffer
                zStream.avail_in = uInt(compressedBytesCount)
            }
            
            status = inflate(&zStream, Z_NO_FLUSH)
            if status == Z_STREAM_END { // end of input, all the output has been produced
                try finalize()
                isEndOfInput = true
                let producedByteCount = outChunkSize - Int(zStream.avail_out)
                return producedByteCount
            }
            guard status == Z_OK else {
                let error = GzipStreamError(code: status, msg: zStream.msg)
                inflateEnd(&zStream)
                throw error
            }
            // some progress has been made, continue filling out the buffer
        } while zStream.avail_out > 0
        return outChunkSize
    }

    private func finalize() throws {
        let state = inflateEnd(&zStream)
        if state != Z_OK {
            throw GzipStreamError(code: state, msg: zStream.msg)
        }
    }
    
    public func close() {
        assert(wasOpened, "Tried to close a stream that was never opened.")
        _ = inflateEnd(&zStream)
    }
}
