import Foundation
import NaturalLanguage
import OSLog

/// 파싱된 원문에서 전체 후보를 생성하고 seed42 점수와 최종 선택 규칙을 적용합니다.
nonisolated public final class R117TermExtractor: Sendable {
    public static let shared = R117TermExtractor()
    /// 압축본 same87 한영 동일 가중 Recall@50 기준으로 선택한 배포 head입니다.
    public static let deploymentHeadFunction = "r117_seed42"
    static var resourceDirectory: URL? {
        Bundle.module.url(forResource: "R117", withExtension: nil)
    }
    private let runtime = R117ExtractionRuntime()

    public func extract(from text: String) async throws -> [String] {
        try Task.checkCancellation()
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        return try await runtime.extract(text)
    }
}

nonisolated public enum R117ExtractionError: LocalizedError, Sendable {
    case resourcesUnavailable

    public var errorDescription: String? {
        "용어 추출 기능을 사용할 수 없어요. 용어를 직접 입력해 주세요."
    }
}

private actor R117ExtractionRuntime {
    private var generator: R117NativeCandidateGenerator?
    private var ranker: R117Ranker?
    private let logger = Logger(subsystem: "com.labcord", category: "R117")

    func extract(_ text: String) async throws -> [String] {
        let clock = ContinuousClock()
        let started = clock.now
        defer {
            let elapsed = String(describing: started.duration(to: clock.now))
            logger.info("R117 extraction finished after \(elapsed, privacy: .public)")
        }
        try Task.checkCancellation()
        guard let resources = R117TermExtractor.resourceDirectory else {
            throw R117ExtractionError.resourcesUnavailable
        }
        let generator: R117NativeCandidateGenerator
        if let cached = self.generator {
            generator = cached
        } else {
            generator = R117NativeCandidateGenerator(resourceDirectory: resources)
            self.generator = generator
        }
        let language = NLLanguageRecognizer.dominantLanguage(for: text) == .korean ? "ko" : "en"
        let pool = try await generator.generate(text: text, language: language)
        try Task.checkCancellation()
        let groups = try R117ShortlistBuilder.build(source: text, pool: pool)
        guard !groups.isEmpty else { return [] }
        let spans = try groups.map { group -> R117CandidateSpan in
            guard let mention = group.featureMention else {
                throw R117RuntimeError.invalidCandidate
            }
            return R117CandidateSpan(
                surface: mention.surface, start: mention.start, end: mention.end
            )
        }
        let ranker: R117Ranker
        if let cached = self.ranker {
            ranker = cached
        } else {
            ranker = try R117Ranker(resourceDirectory: resources)
            self.ranker = ranker
        }
        let result = try ranker.scores(text: text, spans: spans)
        let candidates = try groups.enumerated().map { index, group in
            try group.selectionCandidate(index: index, source: text,
                                         frozenScore: result.frozenScores[index])
        }
        let selected = try R117Selector.select(
            from: candidates, source: text, scores: result.scores
        )
        try Task.checkCancellation()
        return selected.map { candidates[$0].text }
    }
}
