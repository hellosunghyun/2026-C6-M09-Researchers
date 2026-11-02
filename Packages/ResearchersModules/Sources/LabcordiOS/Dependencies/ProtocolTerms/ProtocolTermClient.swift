import ComposableArchitecture
import Foundation

/// 실제 추출·분류 작업에서 관찰한 현재 단계입니다. 예상 진행률을 뜻하지 않습니다.
nonisolated public enum ProtocolTermProgress: Equatable, Sendable {
    case preparingExtraction
    case extractingCandidates
    case preparingRanking
    case rankingCandidates(Int)
    case classifyingTerms(completed: Int, total: Int)
    case organizingTerms
}

/// 파싱된 프로토콜 본문에서 용어를 추출(R117)하고 분류(Foundation Model)합니다.
public struct ProtocolTermClient: Sendable {
    public typealias Progress = @Sendable (ProtocolTermProgress) async -> Void
    public var extract: @Sendable (String) async throws -> ProtocolExtractedTerms
    public var extractWithProgress: @Sendable (
        String, Progress?
    ) async throws -> ProtocolExtractedTerms

    public init(extract: @escaping @Sendable (String) async throws -> ProtocolExtractedTerms) {
        self.extract = extract
        extractWithProgress = { text, _ in try await extract(text) }
    }

    public init(
        extractWithProgress: @escaping @Sendable (
            String, Progress?
        ) async throws -> ProtocolExtractedTerms
    ) {
        self.extractWithProgress = extractWithProgress
        extract = { text in try await extractWithProgress(text, nil) }
    }
}

extension ProtocolTermClient: DependencyKey {
    public static let liveValue = ProtocolTermClient { text, progress in
        let terms = try await R117TermExtractor.shared.extract(from: text, progress: progress)
        try Task.checkCancellation()
        return try await ProtocolTermClassifier.classify(terms, context: text, progress: progress)
    }

    public static let testValue = ProtocolTermClient { _ in ProtocolExtractedTerms() }
    public static let previewValue = testValue
}

public extension DependencyValues {
    var protocolTermClient: ProtocolTermClient {
        get { self[ProtocolTermClient.self] }
        set { self[ProtocolTermClient.self] = newValue }
    }
}
