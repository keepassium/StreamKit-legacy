import XCTest
@testable import StreamKit

final class DataInputStreamTests: XCTestCase {
    private func checkDataInputStream(dataToRead: Data) throws {
        let inStream = DataInputStream(from: dataToRead)
        try inStream.open()
        defer {
            inStream.close()
        }
        
        var buffer = Data(count: dataToRead.count * 2)
        let bufferSize = buffer.count
        let readCount = try buffer.withUnsafeMutableBytes {
            let ptr = $0.baseAddress!.assumingMemoryBound(to: UInt8.self)
            return try inStream.read(ptr, maxCount: bufferSize)
        }
        buffer.count = readCount // trim
        let dataRead = buffer
        XCTAssertEqual(dataToRead, dataRead)
    }
    
    func testEmptyDataInputStream() throws {
        try checkDataInputStream(dataToRead: Data())
    }
    
    func testShortDataInputStream() throws {
        try checkDataInputStream(dataToRead: "Hello".data(using: .utf8)!)
    }
    
    func testLongDataInputStream() throws {
        let data = Data(repeating: 123, count: 100_000)
        try checkDataInputStream(dataToRead: data)
    }
}
