import XCTest
@testable import MaresPuckProDriver

final class MaresPuckProDriverTests: XCTestCase {
    
    func testMaresProtocolCommandCreation() {
        // Test CMD_VERSION command creation
        let versionCommand = MaresProtocol.createVersionCommand()
        let expectedCommand = Data([0xC2, 0xC2 ^ 0xA5]) // CMD_VERSION ^ XOR
        
        XCTAssertEqual(versionCommand, expectedCommand)
    }
    
    func testMaresProtocolResponseParsing() {
        // Test valid response parsing
        let validResponse = Data([MaresProtocol.ACK, 0x01, 0x02, 0x03, MaresProtocol.END])
        let parseResult = MaresProtocol.parseResponse(validResponse)
        
        switch parseResult {
        case .success(let payload):
            XCTAssertEqual(payload, Data([0x01, 0x02, 0x03]))
        case .failure:
            XCTFail("Should have parsed valid response successfully")
        }
        
        // Test invalid response (no ACK)
        let invalidResponse = Data([0x00, 0x01, 0x02, MaresProtocol.END])
        let invalidResult = MaresProtocol.parseResponse(invalidResponse)
        
        switch invalidResult {
        case .success:
            XCTFail("Should have failed on invalid response")
        case .failure(let error):
            if case .unexpectedHeader(let byte) = error {
                XCTAssertEqual(byte, 0x00)
            } else {
                XCTFail("Wrong error type")
            }
        }
    }
    
    func testDiveDataCreation() {
        let dive = DiveData(
            diveNumber: 1,
            date: Date(),
            duration: 2340, // 39 minutes
            maxDepth: 18.5,
            averageDepth: 12.3,
            waterType: .saltwater
        )
        
        XCTAssertEqual(dive.diveNumber, 1)
        XCTAssertEqual(dive.formattedDuration, "39:00")
        XCTAssertEqual(dive.formattedMaxDepth, "18.5 m")
        XCTAssertEqual(dive.waterType, .saltwater)
    }
    
    func testDiveDataFormatting() {
        let dive = DiveData(
            diveNumber: 2,
            date: Date(),
            duration: 1980, // 33 minutes
            maxDepth: 15.2,
            averageDepth: 9.8,
            waterType: .freshwater,
            minTemperature: 22.5,
            maxTemperature: 24.5
        )
        
        XCTAssertEqual(dive.formattedDuration, "33:00")
        XCTAssertEqual(dive.formattedMaxDepth, "15.2 m")
        XCTAssertEqual(dive.formattedTemperatureRange, "22.5°C - 24.5°C")
        XCTAssertFalse(dive.hasDecompressionStops)
    }
}