import ComposableArchitecture
import Foundation
import OmniParser

nonisolated public struct ProtocolAnalysisInput: Equatable, Sendable {
    public let id: UUID
    public let url: URL

    public init(id: UUID, url: URL) {
        self.id = id
        self.url = url
    }
}

nonisolated public enum ProtocolAnalysisOutcome: Equatable, Sendable {
    case success(DocumentParseResult)
    case failure(DocumentParsingError)
}

nonisolated public struct ProtocolAnalysisItem: Equatable, Sendable {
    public let id: UUID
    public let outcome: ProtocolAnalysisOutcome
}

public struct ProtocolAnalysisClient: Sendable {
    public typealias Progress = @Sendable (UUID, DocumentProgress) -> Void

    public var parse: @Sendable (
        [ProtocolAnalysisInput], Progress?
    ) async throws -> [ProtocolAnalysisItem]

    public init(
        parse: @escaping @Sendable (
            [ProtocolAnalysisInput], Progress?
        ) async throws -> [ProtocolAnalysisItem]
    ) {
        self.parse = parse
    }
}

extension ProtocolAnalysisClient: DependencyKey {
    public static let liveValue = ProtocolAnalysisClient { inputs, progress in
        let results = try await DocumentParser.parseBatch(
            inputs.map { .url($0.url) },
            options: DocumentParserOptions(performOCR: true)
        ) { event in
            guard inputs.indices.contains(event.inputIndex) else { return }
            progress?(inputs[event.inputIndex].id, event)
        }
        try Task.checkCancellation()
        return zip(inputs, results).map { input, result in
            let outcome: ProtocolAnalysisOutcome
            switch result {
            case let .success(document): outcome = .success(document)
            case let .failure(error): outcome = .failure(error)
            }
            return ProtocolAnalysisItem(id: input.id, outcome: outcome)
        }
    }
}

public extension DependencyValues {
    var protocolAnalysisClient: ProtocolAnalysisClient {
        get { self[ProtocolAnalysisClient.self] }
        set { self[ProtocolAnalysisClient.self] = newValue }
    }
}
