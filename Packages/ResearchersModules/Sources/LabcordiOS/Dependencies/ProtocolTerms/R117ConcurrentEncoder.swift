import CoreML
import Foundation

/// 같은 토큰 입력은 한 번만 추론하고, 동시에 실행하는 async prediction을 둘로 제한합니다.
nonisolated enum R117ConcurrentEncoder {
    struct Features: Sendable {
        let candidate: Int
        let values: [Float]
    }

    typealias Prediction = @Sendable (R117Last2Plan.Group) async throws -> [Features]

    static func last2(
        plan: R117Last2Plan, model: MLModel, candidateCount: Int,
        progress: (@Sendable (Int, Int) -> Void)? = nil
    ) async throws -> [[Float]] {
        let predictor = AsyncModel(model: model)
        return try await last2(plan: plan, candidateCount: candidateCount, progress: progress) {
            try await predictor.predict($0)
        }
    }

    static func last2(
        plan: R117Last2Plan, candidateCount: Int,
        progress: (@Sendable (Int, Int) -> Void)? = nil,
        prediction: @escaping Prediction
    ) async throws -> [[Float]] {
        try Task.checkCancellation()
        try validate(plan, candidateCount: candidateCount)
        return try await withThrowingTaskGroup(of: CompletedGroup.self) { tasks in
            var rows: [[Float]?] = Array(repeating: nil, count: candidateCount)
            var next = min(2, plan.groups.count)
            var completed = 0
            var nextProgress = 20
            for index in 0..<next {
                submit(plan.groups[index], to: &tasks, prediction: prediction)
            }
            while let result = try await tasks.next() {
                try Task.checkCancellation()
                try store(result, in: &rows)
                completed += result.features.count
                if completed >= nextProgress || completed == candidateCount {
                    try Task.checkCancellation()
                    progress?(completed, candidateCount)
                    try Task.checkCancellation()
                    nextProgress = completed + 20
                }
                if next < plan.groups.count {
                    try Task.checkCancellation()
                    submit(plan.groups[next], to: &tasks, prediction: prediction)
                    next += 1
                }
            }
            try Task.checkCancellation()
            return try rows.map { row in
                guard let row else { throw R117RuntimeError.invalidModelOutput }
                return row
            }
        }
    }
}

private extension R117ConcurrentEncoder {
    private struct CompletedGroup: Sendable {
        let group: R117Last2Plan.Group
        let features: [Features]
    }

    private static func validate(_ plan: R117Last2Plan, candidateCount: Int) throws {
        guard candidateCount >= 0 else { throw R117RuntimeError.invalidCandidate }
        let candidates = plan.groups.flatMap { $0.selections.map(\.candidate) }
        guard candidates.count == candidateCount, Set(candidates).count == candidateCount,
              candidates.allSatisfy({ (0..<candidateCount).contains($0) }) else {
            throw R117RuntimeError.invalidCandidate
        }
    }

    private static func submit(
        _ group: R117Last2Plan.Group, to tasks: inout ThrowingTaskGroup<CompletedGroup, Error>,
        prediction: @escaping Prediction
    ) {
        tasks.addTask {
            try Task.checkCancellation()
            let features = try await prediction(group)
            try Task.checkCancellation()
            return CompletedGroup(group: group, features: features)
        }
    }

    private static func store(_ result: CompletedGroup, in rows: inout [[Float]?]) throws {
        let expected = Set(result.group.selections.map(\.candidate))
        guard result.features.count == expected.count else {
            throw R117RuntimeError.invalidModelOutput
        }
        for features in result.features {
            guard expected.contains(features.candidate), rows.indices.contains(features.candidate),
                  rows[features.candidate] == nil, features.values.count == 384,
                  features.values.allSatisfy(\.isFinite) else {
                throw R117RuntimeError.invalidModelOutput
            }
            rows[features.candidate] = features.values
        }
    }

    // 공유 모델은 Apple이 동시 호출을 지원하는 async API로만 사용합니다.
    // https://developer.apple.com/videos/play/wwdc2023/10049/
    // SDK가 모델의 Sendable 적합성을 제공하면 이 한정 wrapper를 제거합니다.
    private final class AsyncModel: @unchecked Sendable {
        private let model: MLModel

        init(model: MLModel) {
            self.model = model
        }

        func predict(_ group: R117Last2Plan.Group) async throws -> [Features] {
            try Task.checkCancellation()
            let input = try R117Tensor.input(ids: group.ids)
            let prediction = try await model.prediction(
                from: input, options: MLPredictionOptions()
            )
            try Task.checkCancellation()
            let output = try R117Tensor.embeddings(from: prediction, length: group.ids.count)
            return try group.selections.map { selection in
                try Task.checkCancellation()
                return Features(
                    candidate: selection.candidate,
                    values: R117Tensor.pooled(output, selected: selection.tokens)
                )
            }
        }
    }
}
