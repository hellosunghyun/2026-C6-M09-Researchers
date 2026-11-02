import Foundation
@testable import LabcordiOS
import XCTest

final class R117DocumentFeaturesTests: XCTestCase {
    func testWeightedContextAndCandidateFeaturesRemainInColumnOrder() throws {
        let document = R117Encoder.Document(
            offsets: [0..<1, 2..<5],
            vectors: [Array(repeating: 1, count: 384), Array(repeating: 3, count: 384)]
        )
        let values = try document.relativeFeatures(text: "A BCD", spans: [0..<1])
        XCTAssertEqual(Array(values[0].prefix(384)), Array(repeating: 1, count: 384))
        XCTAssertEqual(Array(values[0][384..<768]), Array(repeating: 2.5, count: 384))
        XCTAssertEqual(values[0][768], 1, accuracy: 1e-6)
        let purpose = try document.relativeFeatures(
            text: "A BCD", spans: [2..<5], contextTokenLimit: 1
        )
        XCTAssertEqual(Array(purpose[0].prefix(768)), Array(repeating: 3, count: 768))
    }

    func testWhitespaceAndControlDoNotRequireTokenCoverage() throws {
        let document = R117Encoder.Document(
            offsets: [0..<1, 4..<5],
            vectors: [Array(repeating: 1, count: 384), Array(repeating: 1, count: 384)]
        )
        XCTAssertNoThrow(try document.relativeFeatures(text: "A \u{001C}\tB", spans: [0..<5]))
        XCTAssertThrowsError(try document.relativeFeatures(text: "A 🧪 B", spans: [0..<5]))
    }

    func testInvalidSourceRangesAreRejected() throws {
        let document = R117Encoder.Document(
            offsets: [0..<1], vectors: [Array(repeating: 1, count: 384)]
        )
        for range in [-1..<1, 0..<0, 0..<2] {
            XCTAssertThrowsError(try document.relativeFeatures(text: "A", spans: [range]))
        }
    }
}
