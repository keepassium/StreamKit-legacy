import XCTest
@testable import StreamKit

final class GzipStreamTests: XCTestCase {
}

// MARK: Compression
extension GzipStreamTests {
    func compress(
        data inData: Data,
        chunkSize: Int = GzipOutputStream.defaultChunkSize
    ) throws -> Data {
        let dataOutputStream = DataOutputStream()
        try dataOutputStream.open()
        defer {
            try! dataOutputStream.close()
        }
        
        let compressorStream = GzipOutputStream(writingTo: dataOutputStream, chunkSize: chunkSize)
        try compressorStream.open()
        do {
            try inData.withUnsafeBytes { (inBuffer: UnsafeRawBufferPointer) -> Void in
                let inPointer = inBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self)
                try compressorStream.write(inPointer, count: inData.count)
            }
            try! compressorStream.close()
        } catch {
            try? compressorStream.close()
        }
        return dataOutputStream.data
    }
    
    func testCompressEmptyData() throws {
        let inData = Data()
        let outData = try compress(data: inData)
        XCTAssert(outData.count == 20) // header
        XCTAssert(outData[0] == 0x1f)
        XCTAssert(outData[1] == 0x8b)
    }
    
    func testCompressFluffyData() throws {
        let inData = Data((0..<100).compactMap { UInt8($0 / 10) })
        let outData = try compress(data: inData)
        XCTAssert(outData[0] == 0x1f)
        XCTAssert(outData[1] == 0x8b)
        XCTAssert(outData.count < inData.count)
    }
}

// MARK: Decompression
extension GzipStreamTests {
    func decompress(
        data: Data,
        inChunkSize: Int = GzipInputStream.defaultInChunkSize,
        outChunkSize: Int = GzipInputStream.defaultOutChunkSize
    ) throws -> Data {
        let dataInputStream = DataInputStream(from: data)
        try dataInputStream.open()
        defer {
            dataInputStream.close()
        }
        
        let decompressorStream = GzipInputStream(
            readingFrom: dataInputStream,
            inChunkSize: inChunkSize,
            outChunkSize: outChunkSize
        )
        try decompressorStream.open()
        defer {
            decompressorStream.close()
        }
        
        var buf = Array<UInt8>(repeating: 0, count: 65536)
        let bytesRead = try decompressorStream.read(&buf, maxCount: buf.count)
        return Data(bytes: &buf, count: bytesRead)
    }
    
    func testDecompressEmptyStream() throws {
        let inData = Data()
        let outData = try decompress(data: inData)
        XCTAssert(outData.isEmpty)
    }
    
    func testDecompressRandomData() throws {
        let randomBytes = (0..<100).map { _ in UInt8.random(in: 0..<255) }
        let inData = Data(bytes: randomBytes, count: randomBytes.count)
        
        XCTAssertThrowsError(try decompress(data: inData)) { error in
            XCTAssert((error as! GzipStreamError).kind == .dataError)
        }
    }
}

// MARK: Compress then decompress
extension GzipStreamTests {
    private static let dataSizes = [1, 10, 32, 128, 256, 1000, 1024, 2048]
    
    func compressDecompress(data inData: Data) throws {
        let chunkSizes = [8, 32, 256, 1024]
        for chunkSize in chunkSizes {
            for inChunkSize in chunkSizes {
                for outChunkSize in chunkSizes {
                    let compressed = try compress(data: inData, chunkSize: chunkSize)
                    let decompressed = try decompress(
                        data: compressed,
                        inChunkSize: inChunkSize,
                        outChunkSize: outChunkSize
                    )
                    XCTAssertEqual(inData, decompressed)
                }
            }
        }
    }
    
    func testCompressDecompressEmptyData() throws {
        try compressDecompress(data: Data())
    }

    func testCompressDecompressZeroedData() throws {
        for dataSize in Self.dataSizes {
            let inData = Data(repeating: 0, count: dataSize)
            try compressDecompress(data: inData)
        }
    }

    func testCompressDecompressFluffyData() throws {
        for dataSize in Self.dataSizes {
            let fluffyData = Data((0..<dataSize).compactMap { UInt8($0 / 10) })
            try compressDecompress(data: fluffyData)
        }
    }

    func testCompressDecompressRandomData() throws {
        for dataSize in Self.dataSizes {
            let randomData = Data((0..<dataSize).compactMap { _ in UInt8.random(in: 0..<255) })
            try compressDecompress(data: randomData)
        }
    }
}
