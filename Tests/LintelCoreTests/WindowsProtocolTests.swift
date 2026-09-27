import Foundation
import Testing
@testable import LintelCore

/// Shared wire fixtures are validated by both hosts; Windows does not invent a second v1 format.
@Suite("Windows 共用活动样例")
struct WindowsProtocolTests {
    @Test("Windows 最小与完整样例通过 Swift 校验，并能解码再编码")
    func sharedFixtures() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        for name in ["minimal", "full"] {
            let url = root.appendingPathComponent("windows/fixtures/\(name).json")
            let data = try Data(contentsOf: url)
            let (activity, rejects) = Validation.check(data: data, producer: "willow", file: "\(name).json",
                                                       registered: ["choice", "declaration"])
            #expect(rejects.isEmpty, "\(rejects)")
            let decoded = try #require(activity)
            let encoded = try LintelJSON.encoder.encode(decoded)
            let (roundTrip, errors) = Validation.check(data: encoded, producer: "willow", file: "\(name).json",
                                                       registered: ["choice", "declaration"])
            #expect(errors.isEmpty)
            #expect(roundTrip == decoded)
        }
    }
}
