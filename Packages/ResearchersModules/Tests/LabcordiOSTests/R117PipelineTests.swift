import Foundation
import FoundationModels
@testable import LabcordiOS
import LabcordShared
import XCTest

final class R117PipelineTests: XCTestCase {
    private let source = "Add sodium chloride to phosphate buffer and centrifuge for 5 min."

    @MainActor
    func testParsedProtocolRoundTripPreservesSpeechHints() async throws {
        let identifier = UUID()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("protocol-\(identifier).txt")
        try source.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        let parsed = try await ProtocolAnalysisClient.liveValue.parse(
            [ProtocolAnalysisInput(id: identifier, url: url)], nil
        )
        let text = try XCTUnwrap(parsed.first?.extractedText)
        let terms = try await ProtocolTermClient.liveValue.extract(text)
        XCTAssertFalse(terms.isEmpty)
        print("Foundation Model availability: \(SystemLanguageModel.default.availability)")
        print("Foundation Model fallback used: \(terms.usedFallback)")
        if SystemLanguageModel.default.isAvailable {
            XCTAssertFalse(terms.usedFallback, "Classification included fallback labels")
        }
        for term in terms.all { XCTAssertTrue(text.contains(term)) }
        let timers = ProtocolTimerExtractor.extract(from: text)
        XCTAssertEqual(timers, [300])
        let client = ExperimentClient.liveValue
        let experiment = ExperimentProtocol(
            timerSeconds: timers, materials: terms.materials, samples: terms.samples,
            glossaryTerms: terms.glossaryTerms, units: terms.units
        )
        _ = try client.createWithProtocol(identifier, .now, "Simulator protocol QA", experiment)
        defer { try? client.delete(identifier) }
        let detail = try XCTUnwrap(client.loadDetail(identifier))
        XCTAssertEqual(Set(detail.speechContextualStrings), Set(terms.all))
        XCTAssertEqual(detail.timerSeconds, timers)
    }

    func testExtractionTimeAndMemory() {
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()], options: options) {
            let finished = expectation(description: "R117 extraction")
            Task {
                do {
                    let terms = try await R117TermExtractor.shared.extract(from: source)
                    XCTAssertFalse(terms.isEmpty)
                } catch {
                    XCTFail("Extraction failed: \(error)")
                }
                finished.fulfill()
            }
            wait(for: [finished], timeout: 120)
        }
    }
}
