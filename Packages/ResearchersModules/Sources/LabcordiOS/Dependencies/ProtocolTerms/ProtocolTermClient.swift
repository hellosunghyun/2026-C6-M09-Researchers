import ComposableArchitecture
import Foundation

/// 파싱된 프로토콜 본문에서 용어를 추출(R117)하고 분류(Foundation Model)합니다.
public struct ProtocolTermClient: Sendable {
    public var extract: @Sendable (String) async throws -> ProtocolExtractedTerms

    public init(extract: @escaping @Sendable (String) async throws -> ProtocolExtractedTerms) {
        self.extract = extract
    }
}

extension ProtocolTermClient: DependencyKey {
    public static let liveValue = ProtocolTermClient { text in
        let terms = try await R117TermExtractor.shared.extract(from: text)
        try Task.checkCancellation()
        return try await ProtocolTermClassifier.classify(terms, context: text)
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
