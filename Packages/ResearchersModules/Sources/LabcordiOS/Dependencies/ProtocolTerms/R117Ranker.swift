import Dispatch
import Foundation

/// 모든 후보의 특징·점수 배열은 같은 순서를 유지합니다.
nonisolated final class R117Ranker {
    private let runner: R117HeadRunner
    private let encoder: R117Encoder
    private let frozenModel: Data

    init(resourceDirectory: URL) throws {
        runner = try R117HeadRunner(resourceDirectory: resourceDirectory)
        let tokenizer = try R117Tokenizer(
            url: resourceDirectory.appendingPathComponent("tokenizer/tokenizer.json")
        )
        encoder = R117Encoder(tokenizer: tokenizer, runner: runner)
        frozenModel = try Data(
            contentsOf: resourceDirectory.appendingPathComponent("frozen9.model.json")
        )
    }

    func scores(
        text: String,
        spans: [R117CandidateSpan],
        observation: ((String, Double) -> Void)? = nil,
        includeTrace: Bool = false,
        precomputedLast2: [[Float]]? = nil,
        precomputedDocuments: Documents? = nil,
        candidateProgress: (@Sendable (Int, Int) -> Void)? = nil
    ) throws -> Result {
        try Task.checkCancellation()
        guard !spans.isEmpty else { throw R117RuntimeError.invalidCandidate }
        let ranges = spans.map { $0.start..<$0.end }
        let original = try document(
            text: text, function: "r117_original", precomputed: precomputedDocuments?.original,
            observation: observation
        )
        let originalFeatures = try measure("original_relative_features", observation) {
            try original.relativeFeatures(text: text, spans: ranges)
        }
        let head = try measure("deployment_head", observation) {
            try runner.predictHead(
                function: R117TermExtractor.deploymentHeadFunction, features: originalFeatures
            )
        }
        let components = try teacherComponents(
            text: text, spans: spans, ranges: ranges, observation: observation,
            input: TeacherInput(
                document: precomputedDocuments?.teacher, last2Features: precomputedLast2,
                progress: candidateProgress
            )
        )
        let combined = try measure("score_combination", observation) {
            try R117ScoringMath.combine(components, headLogits: head)
        }
        return Result(
            scores: combined,
            frozenScores: components.frozen9,
            trace: includeTrace ? Trace(components: components, headLogits: head) : nil
        )
    }

    /// 문서 두 모델의 인코딩을 함께 마친 뒤 후보별 추론을 시작합니다.
    /// 가변 모델 캐시 접근과 나머지 점수 계산은 호출 actor에 남깁니다.
    func scoresConcurrently(
        text: String,
        spans: [R117CandidateSpan],
        isolation: isolated (any Actor)? = #isolation,
        observation: ((String, Double) -> Void)? = nil,
        includeTrace: Bool = false,
        candidateProgress: (@Sendable (Int, Int) -> Void)? = nil
    ) async throws -> Result {
        try Task.checkCancellation()
        guard !spans.isEmpty else { throw R117RuntimeError.invalidCandidate }
        let documentStarted = observation == nil ? nil : DispatchTime.now().uptimeNanoseconds
        let prepared = try encoder.prepareDocuments(text: text)
        async let original = prepared.original.document()
        async let teacher = prepared.teacher.document()
        let (originalDocument, teacherDocument) = try await (original, teacher)
        try Task.checkCancellation()
        if let documentStarted {
            observation?("document_encoders_concurrent",
                         Double(DispatchTime.now().uptimeNanoseconds - documentStarted)
                            / 1_000_000_000)
        }
        let started = observation == nil ? nil : DispatchTime.now().uptimeNanoseconds
        let features = try await encoder.last2Concurrently(
            text: text, spans: spans.map { $0.start..<$0.end }, progress: candidateProgress
        )
        if let started {
            observation?("teacher_last2_features",
                         Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000_000)
        }
        try Task.checkCancellation()
        return try scores(
            text: text, spans: spans, observation: observation,
            includeTrace: includeTrace, precomputedLast2: features,
            precomputedDocuments: Documents(original: originalDocument, teacher: teacherDocument)
        )
    }

    struct Documents: Sendable {
        let original: R117Encoder.Document
        let teacher: R117Encoder.Document
    }

    struct Result {
        let scores: [Double]
        let frozenScores: [Double]
        let trace: Trace?
    }

    struct Trace {
        let components: R117ScoringMath.Components
        let headLogits: [Double]
    }

    private func teacherComponents(
        text: String,
        spans: [R117CandidateSpan],
        ranges: [Range<Int>],
        observation: ((String, Double) -> Void)?,
        input: TeacherInput
    ) throws -> R117ScoringMath.Components {
        let teacher = try document(
            text: text, function: "teacher_taskfit", precomputed: input.document,
            observation: observation
        )
        let relative = try measure("teacher_relative_features", observation) {
            try teacher.relativeFeatures(text: text, spans: ranges)
        }
        let purposeRelative = try measure("teacher_purpose_features", observation) {
            try teacher.relativeFeatures(text: text, spans: ranges, contextTokenLimit: 512)
        }
        let native = try measure("native_features", observation) {
            try R117ScoringMath.native(count: spans.count)
        }
        let featureDocument = R117HandcraftedFeatures.Document(text: text)
        let nine = try measure("handcrafted_nine", observation) {
            try spans.map { try featureDocument.nine(span: $0) }
        }
        let frozen = try measure("frozen9", observation) {
            try R117ScoringMath.frozen9(features: nine, modelData: frozenModel)
        }
        let features = try measure("handcrafted_32", observation) {
            try spans.map { try featureDocument.combined32(span: $0) }
        }
        let hgb = try measure("teacher_hgb", observation) {
            try runner.predictHGB(features: features)
        }
        let window = try measure("teacher_window_head", observation) {
            try runner.predictHead(function: "teacher_window", features: relative)
        }
        let scope = try measure("teacher_scope_head", observation) {
            try runner.predictHead(function: "teacher_scope", features: relative)
        }
        let purpose = try measure("teacher_purpose_head", observation) {
            try runner.predictHead(function: "teacher_purpose", features: purposeRelative)
        }
        let last2Features = try last2Features(
            text: text, ranges: ranges, observation: observation, input: input
        )
        let last2 = try measure("teacher_last2_head", observation) {
            try runner.predictHead(
                function: "teacher_last2_head", features: last2Features,
                inputName: "pooled_features"
            )
        }
        return R117ScoringMath.Components(
            native: native, frozen9: frozen, hgb: hgb, window: window,
            scope: scope, purpose: purpose, last2: last2
        )
    }

    private struct TeacherInput {
        let document: R117Encoder.Document?
        let last2Features: [[Float]]?
        let progress: (@Sendable (Int, Int) -> Void)?
    }

    private func last2Features(
        text: String, ranges: [Range<Int>], observation: ((String, Double) -> Void)?,
        input: TeacherInput
    ) throws -> [[Float]] {
        if let features = input.last2Features { return features }
        return try measure("teacher_last2_features", observation) {
            try encoder.last2(text: text, spans: ranges, progress: input.progress)
        }
    }

    private func document(
        text: String, function: String, precomputed: R117Encoder.Document?,
        observation: ((String, Double) -> Void)?
    ) throws -> R117Encoder.Document {
        if let precomputed { return precomputed }
        let stage = function == "r117_original"
            ? "original_document_encoder" : "teacher_document_encoder"
        return try measure(stage, observation) {
            try encoder.document(text: text, function: function)
        }
    }

    private func measure<T>(
        _ stage: String, _ observation: ((String, Double) -> Void)?, _ operation: () throws -> T
    ) rethrows -> T {
        guard let observation else { return try operation() }
        let start = DispatchTime.now().uptimeNanoseconds
        defer {
            let elapsed = DispatchTime.now().uptimeNanoseconds - start
            observation(stage, Double(elapsed) / 1_000_000_000)
        }
        return try operation()
    }
}
