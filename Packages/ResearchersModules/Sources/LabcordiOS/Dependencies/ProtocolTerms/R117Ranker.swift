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

    func scores(text: String, spans: [R117CandidateSpan]) throws -> Result {
        try Task.checkCancellation()
        guard !spans.isEmpty else { throw R117RuntimeError.invalidCandidate }
        let ranges = spans.map { $0.start..<$0.end }
        let original = try encoder.document(text: text, function: "r117_original")
        let originalFeatures = try original.relativeFeatures(text: text, spans: ranges)
        let head = try runner.predictHead(
            function: R117TermExtractor.deploymentHeadFunction, features: originalFeatures
        )
        let teacher = try encoder.document(text: text, function: "teacher_taskfit")
        let relative = try teacher.relativeFeatures(text: text, spans: ranges)
        let purposeRelative = try teacher.relativeFeatures(
            text: text, spans: ranges, contextTokenLimit: 512
        )
        let native = try R117ScoringMath.native(count: spans.count)
        let nine = try spans.map { try R117HandcraftedFeatures.nine(text: text, span: $0) }
        let frozen = try R117ScoringMath.frozen9(features: nine, modelData: frozenModel)
        let features = try spans.map {
            try R117HandcraftedFeatures.combined32(text: text, span: $0)
        }
        let components = try R117ScoringMath.Components(
            native: native, frozen9: frozen,
            hgb: runner.predictHGB(features: features),
            window: runner.predictHead(function: "teacher_window", features: relative),
            scope: runner.predictHead(function: "teacher_scope", features: relative),
            purpose: runner.predictHead(function: "teacher_purpose", features: purposeRelative),
            last2: runner.predictHead(
                function: "teacher_last2_head", features: encoder.last2(text: text, spans: ranges),
                inputName: "pooled_features"
            )
        )
        return Result(
            scores: try R117ScoringMath.combine(components, headLogits: head), frozenScores: frozen
        )
    }

    struct Result {
        let scores: [Double]
        let frozenScores: [Double]
    }
}
