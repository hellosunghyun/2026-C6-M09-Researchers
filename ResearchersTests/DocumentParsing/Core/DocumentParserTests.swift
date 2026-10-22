import Foundation
import Synchronization
import XCTest

@testable import Researchers

/// 외부 호출자가 의존하는 실행 문맥·배치 순서·개별 실패·취소 이벤트 계약을 확인한다.
final class DocumentParserTests: XCTestCase {
  @MainActor
  func testParsingLeavesMainActorBeforeReportingProgress() async throws {
    XCTAssertTrue(Thread.isMainThread)
    let input = DocumentInput.data(Data("Background".utf8), fileName: "input.txt")
    _ = try await DocumentParser.parse(input) { _ in
      XCTAssertFalse(Thread.isMainThread)
    }
    XCTAssertTrue(Thread.isMainThread)
  }

  func testBatchPreservesInputOrderAndIndividualFailure() async throws {
    let recorder = ProgressRecorder()
    let inputs: [DocumentInput] = [
      .data(Data("first".utf8), fileName: "first.txt"),
      .data(Data([0, 1, 2, 3, 4]), fileName: "unknown.bin"),
      .data(Data("third".utf8), fileName: "third.txt")
    ]
    let results = try await DocumentParser.parseBatch(
      inputs,
      options: DocumentParserOptions(maximumConcurrentDocuments: 2)
    ) { recorder.append($0) }
    XCTAssertEqual(results.count, 3)
    guard case .success(let first) = results[0],
      case .failure(let second) = results[1],
      case .success(let third) = results[2]
    else {
      return XCTFail("Batch results did not preserve each input outcome.")
    }
    XCTAssertEqual(first.fullText, "first")
    XCTAssertEqual(second, .unsupportedFormat)
    XCTAssertEqual(third.fullText, "third")
    let terminalEvents = recorder.events.filter {
      [.completed, .failed, .cancelled].contains($0.phase)
    }.sorted { $0.inputIndex < $1.inputIndex }
    XCTAssertEqual(terminalEvents.map(\.inputIndex), [0, 1, 2])
    XCTAssertEqual(terminalEvents.map(\.phase), [.completed, .failed, .completed])
  }

  func testCancellationAtExtractionPropagatesAndReportsTerminalEvent() async {
    let recorder = ProgressRecorder()
    let operation = Task {
      let input = DocumentInput.data(Data("Stopped".utf8), fileName: "cancel.txt")
      return try await DocumentParser.parse(input) { event in
        recorder.append(event)
        if event.phase == .extracting {
          withUnsafeCurrentTask { $0?.cancel() }
        }
      }
    }
    do {
      _ = try await operation.value
      XCTFail("Cancelled parsing completed successfully.")
    } catch {
      XCTAssertEqual(error as? DocumentParsingError, .cancelled)
    }
    XCTAssertEqual(recorder.events.last?.phase, .cancelled)
    XCTAssertFalse(recorder.events.contains { $0.phase == .completed })
  }

  func testMutatedZeroConcurrencyStillPreservesBatchResults() async throws {
    var options = DocumentParserOptions()
    options.maximumConcurrentDocuments = 0
    let results = try await DocumentParser.parseBatch(
      [.data(Data("Kept".utf8), fileName: "input.txt")], options: options
    )
    XCTAssertEqual(results.count, 1)
    guard let first = results.first, case .success(let result) = first else {
      return XCTFail("Batch dropped its input result.")
    }
    XCTAssertEqual(result.fullText, "Kept")
  }
  func testCancellationLatencyAndOfficeTemporaryCleanup() async throws {
    let before = try temporaryDirectories()
    let url = try XCTUnwrap(Bundle(for: Self.self).url(
      forResource: "real-hwpx-02-noori", withExtension: "hwpx", subdirectory: "RealWorld/hwpx"))
    _ = try await DocumentParser.parse(.url(url))
    let office = try XCTUnwrap(Bundle(for: Self.self).url(
      forResource: "LegacySample", withExtension: "doc"))
    _ = try await DocumentParser.parse(.url(office))
    let malformed = DocumentArchiveFixtureBuilder.make([
      ("word/document.xml", Data("<broken".utf8))
    ])
    do {
      _ = try await DocumentParser.parse(.data(malformed, fileName: "broken.docx"))
      XCTFail("Malformed Office document completed")
    } catch { XCTAssertFalse(error is CancellationError) }
    let image = try XCTUnwrap(DocumentImageFixtures.textImage("CANCEL LATENCY 123"))
    let data = try DocumentImageFixtures.tiff(Array(repeating: (image, .up), count: 20))
    let started = Mutex(false)
    let task = Task {
      try await DocumentParser.parse(.data(data, fileName: "twenty-frames.tiff")) { event in
        if event.phase == .recognizingText { started.withLock { $0 = true } }
      }
    }
    let deadline = ContinuousClock.now.advanced(by: .seconds(10))
    while !started.withLock({ $0 }), ContinuousClock.now < deadline {
      try await Task.sleep(for: .milliseconds(5))
    }
    XCTAssertTrue(started.withLock { $0 })
    // 즉시 경계 취소와 구분해 Vision 실행 중을 겨냥하여 취소한다.
    try await Task.sleep(for: .milliseconds(20))
    task.cancel()
    do {
      _ = try await task.value
      XCTFail("Cancelled TIFF completed")
    } catch { XCTAssertEqual(error as? DocumentParsingError, .cancelled) }
    XCTAssertEqual(try temporaryDirectories(), before)
  }

  private func temporaryDirectories() throws -> Set<String> {
    Set(try FileManager.default.contentsOfDirectory(
      atPath: FileManager.default.temporaryDirectory.path).filter {
        $0.hasPrefix("DocumentParsing-")
      })
  }

}

nonisolated private final class ProgressRecorder: Sendable {
  private let storage = Mutex<[DocumentProgress]>([])

  var events: [DocumentProgress] {
    storage.withLock { $0 }
  }

  func append(_ event: DocumentProgress) {
    storage.withLock { $0.append(event) }
  }
}
