import Foundation

/// R117 전처리와 최종 선택 로직이 연결되기 전에는 명시적으로 실패합니다.
nonisolated public final class R117TermExtractor: Sendable {
    public static let shared = R117TermExtractor()

    public func extract(from text: String) async throws -> [String] {
        try Task.checkCancellation()
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        throw R117ExtractionError.runtimeNotIntegrated
    }
}

nonisolated public enum R117ExtractionError: LocalizedError, Sendable {
    case runtimeNotIntegrated

    public var errorDescription: String? {
        "용어 추출 기능을 사용할 수 없어요. 용어를 직접 입력해 주세요."
    }
}
