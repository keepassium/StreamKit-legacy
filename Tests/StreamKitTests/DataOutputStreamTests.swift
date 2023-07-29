import XCTest
@testable import StreamKit

final class DataOutputStreamTests: XCTestCase {
    private func checkDataOutputStream(dataToWrite: Data) throws {
        let outStream = DataOutputStream()
        try outStream.open()
        defer {
            try! outStream.close()
        }
        try dataToWrite.withUnsafeBytes {
            let ptr = $0.baseAddress!.assumingMemoryBound(to: UInt8.self)
            try outStream.write(ptr, count: dataToWrite.count)
        }
        let dataWritten = outStream.data
        XCTAssertEqual(dataToWrite, dataWritten)
    }
    
    func testEmptyDataOutputStream() throws {
        try checkDataOutputStream(dataToWrite: Data())
    }
    
    func testShortDataOutputStream() throws {
        try checkDataOutputStream(dataToWrite: "Hello".data(using: .utf8)!)
    }
    
    func testLongDataOutputStream() throws {
        let data = Data(repeating: 123, count: 100_000)
        try checkDataOutputStream(dataToWrite: data)
    }
}
