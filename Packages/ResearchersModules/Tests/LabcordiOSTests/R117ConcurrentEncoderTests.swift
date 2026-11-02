import Foundation
@testable import LabcordiOS
import XCTest

final class R117ConcurrentEncoderTests: XCTestCase {
    private static let tokenizer = Result {
        let directory = try XCTUnwrap(R117TermExtractor.resourceDirectory)
        return try R117Tokenizer(
            url: directory.appendingPathComponent("tokenizer/tokenizer.json")
        )
    }

    func testTwoPredictionsRestoreCandidateOrderAndInferSharedInputOnce() async throws {
        let plan = try plan(spans: [0..<6, 406..<414, 0..<6, 814..<820])
        let predictor = ReorderedPredictor()
        let result = try await R117ConcurrentEncoder.last2(plan: plan, candidateCount: 4) {
            try await predictor.predict($0)
        }
        XCTAssertEqual(result.count, 4)
        for (candidate, values) in result.enumerated() {
            XCTAssertEqual(values, Array(repeating: Float(candidate), count: 384))
        }
        let metrics = await predictor.metrics()
        XCTAssertEqual(metrics.started.sorted(), [0, 1, 3])
        XCTAssertEqual(metrics.finished.first, 1)
        XCTAssertEqual(metrics.peak, 2)
    }

    func testProgressCountsReadyCandidatesAndFinishesAtTotal() async throws {
        let spans = Array(repeating: 0..<6, count: 21)
            + Array(repeating: 406..<414, count: 22)
            + Array(repeating: 814..<820, count: 17)
        let plan = try plan(spans: spans)
        let progress = ProgressRecorder()
        _ = try await R117ConcurrentEncoder.last2(
            plan: plan, candidateCount: spans.count,
            progress: { progress.append($0, $1) },
            prediction: { group in
                group.selections.map { selection in
                    .init(candidate: selection.candidate, values: Array(repeating: 0, count: 384))
                }
            }
        )
        let events = progress.snapshot()
        XCTAssertFalse(events.isEmpty)
        XCTAssertEqual(events.last?.completed, 60)
        XCTAssertTrue(events.allSatisfy { $0.total == 60 })
        let possibleReadyCounts = Set([21, 22, 38, 39, 43, 60])
        XCTAssertTrue(events.allSatisfy { possibleReadyCounts.contains($0.completed) })
        for (previous, current) in zip(events, events.dropFirst()) {
            XCTAssertGreaterThan(current.completed, previous.completed)
            XCTAssertTrue(current.completed - previous.completed >= 20 || current.completed == 60)
        }
    }

    func testCancellationStopsInFlightWorkWithoutLateProgress() async throws {
        let plan = try plan(spans: [0..<6, 406..<414, 814..<820])
        let gate = StartGate()
        let progress = ProgressRecorder()
        let task = Task {
            try await R117ConcurrentEncoder.last2(
                plan: plan, candidateCount: 3, progress: { progress.append($0, $1) },
                prediction: { group in
                    await gate.markStarted()
                    try await Task.sleep(for: .seconds(30))
                    return group.selections.map { selection in
                        .init(candidate: selection.candidate,
                              values: Array(repeating: 0, count: 384))
                    }
                }
            )
        }
        await gate.waitForStart()
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("취소된 작업이 완료 결과를 반환함")
        } catch is CancellationError {
            XCTAssertTrue(progress.snapshot().isEmpty)
        }
    }

    func testCancelledTaskDoesNotStartPrediction() async throws {
        let plan = try plan(spans: [0..<6])
        let progress = ProgressRecorder()
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await R117ConcurrentEncoder.last2(
                plan: plan, candidateCount: 1, progress: { progress.append($0, $1) },
                prediction: { _ in throw TestFailure.unexpectedPrediction }
            )
        }
        do {
            _ = try await task.value
            XCTFail("이미 취소된 작업이 결과를 반환함")
        } catch is CancellationError {
            XCTAssertTrue(progress.snapshot().isEmpty)
        }
    }

    func testWrongCandidateCountIsRejectedBeforePrediction() async throws {
        let plan = try plan(spans: [0..<6])
        for count in [-1, 0, 2] {
            do {
                _ = try await R117ConcurrentEncoder.last2(plan: plan, candidateCount: count) { _ in
                    throw TestFailure.unexpectedPrediction
                }
                XCTFail("후보 수 불일치를 허용함")
            } catch R117RuntimeError.invalidCandidate {
                // 결과 배열을 만들기 전에 계획과 후보 수의 일치를 확인합니다.
            }
        }
    }

    private func plan(spans: [Range<Int>]) throws -> R117Last2Plan {
        try R117Last2Plan(
            text: "sodium" + String(repeating: " ", count: 400) + "chloride"
                + String(repeating: " ", count: 400) + "buffer",
            spans: spans, tokenizer: Self.tokenizer.get()
        )
    }
}

private enum TestFailure: Error {
    case unexpectedPrediction
}

private actor ReorderedPredictor {
    struct Metrics: Sendable {
        let started: [Int]
        let finished: [Int]
        let peak: Int
    }

    private var started: [Int] = []
    private var finished: [Int] = []
    private var active = 0
    private var peak = 0
    private var firstStarted = false
    private var thirdStarted = false
    private var waitingForFirst: CheckedContinuation<Void, Never>?
    private var waitingForThird: CheckedContinuation<Void, Never>?

    func predict(_ group: R117Last2Plan.Group) async throws -> [R117ConcurrentEncoder.Features] {
        guard let candidate = group.selections.first?.candidate else {
            throw TestFailure.unexpectedPrediction
        }
        started.append(candidate)
        active += 1
        peak = max(peak, active)
        defer { active -= 1 }
        if candidate == 0 {
            firstStarted = true
            waitingForFirst?.resume()
            waitingForFirst = nil
            if !thirdStarted { await withCheckedContinuation { waitingForThird = $0 } }
        } else if candidate == 1 && !firstStarted {
            await withCheckedContinuation { waitingForFirst = $0 }
        } else if candidate == 3 {
            thirdStarted = true
            waitingForThird?.resume()
            waitingForThird = nil
        }
        finished.append(candidate)
        return group.selections.map { selection in
            .init(candidate: selection.candidate,
                  values: Array(repeating: Float(selection.candidate), count: 384))
        }
    }

    func metrics() -> Metrics {
        Metrics(started: started, finished: finished, peak: peak)
    }
}

private actor StartGate {
    private var started = false
    private var waiter: CheckedContinuation<Void, Never>?

    func markStarted() {
        started = true
        waiter?.resume()
        waiter = nil
    }

    func waitForStart() async {
        if !started { await withCheckedContinuation { waiter = $0 } }
    }
}

private final class ProgressRecorder: @unchecked Sendable {
    struct Event: Sendable {
        let completed: Int
        let total: Int
    }

    private let lock = NSLock()
    private var events: [Event] = []

    func append(_ completed: Int, _ total: Int) {
        lock.lock()
        defer { lock.unlock() }
        events.append(Event(completed: completed, total: total))
    }

    func snapshot() -> [Event] {
        lock.lock()
        defer { lock.unlock() }
        return events
    }
}
