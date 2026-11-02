import CoreML
import Foundation

nonisolated final class R117Encoder {
    struct Document {
        let offsets: [Range<Int>]
        let vectors: [[Double]]

        func pooled(in range: Range<Int>) throws -> [Float] {
            let overlaps = offsets.map { max(0, min($0.upperBound, range.upperBound)
                - max($0.lowerBound, range.lowerBound)) }
            let total = overlaps.reduce(0, +)
            guard total > 0 else { throw R117RuntimeError.uncoveredSource }
            var output = Array(repeating: 0.0, count: 384)
            for (index, weight) in overlaps.enumerated() where weight > 0 {
                let scale = Double(Float(weight) / Float(total))
                for column in 0..<384 { output[column] += vectors[index][column] * scale }
            }
            return output.map(Float.init)
        }

        func validateCoverage(text: String, range: Range<Int>) throws {
            let scalars = Array(text.unicodeScalars)
            guard range.lowerBound >= 0, range.upperBound <= scalars.count, !range.isEmpty else {
                throw R117RuntimeError.invalidCandidate
            }
            for position in range where !scalars[position].properties.isWhitespace {
                let scalar = scalars[position]
                if scalar.properties.generalCategory == .control { continue }
                guard offsets.contains(where: { $0.contains(position) }) else {
                    throw R117RuntimeError.uncoveredSource
                }
            }
        }

        func relativeFeatures(
            text: String, spans: [Range<Int>], contextTokenLimit: Int? = nil
        ) throws -> [[Float]] {
            let count = text.unicodeScalars.count
            let context: Document
            if let limit = contextTokenLimit {
                context = Document(
                    offsets: Array(offsets.prefix(limit)), vectors: Array(vectors.prefix(limit))
                )
            } else {
                context = self
            }
            let document = try context.pooled(in: 0..<count)
            return try spans.map { range in
                try validateCoverage(text: text, range: range)
                return R117Encoder.relative(try pooled(in: range), context: document)
            }
        }
    }

    private let tokenizer: R117Tokenizer
    private let runner: R117HeadRunner

    init(tokenizer: R117Tokenizer, runner: R117HeadRunner) {
        self.tokenizer = tokenizer
        self.runner = runner
    }

    func document(text: String, function: String) throws -> Document {
        let encoding = try tokenizer.encode(text)
        guard !encoding.ids.isEmpty else { throw R117RuntimeError.uncoveredSource }
        let model = try runner.model(function: function)
        let empty = Array(repeating: Float(0), count: 384)
        var sums = Array(repeating: empty, count: encoding.ids.count)
        var counts = Array(repeating: 0, count: encoding.ids.count)
        for start in stride(from: 0, to: encoding.ids.count, by: 448) {
            try Task.checkCancellation()
            let end = min(start + 512, encoding.ids.count)
            let hidden = try predict(model: model, ids: Array(encoding.ids[start..<end]))
            for index in start..<end {
                for column in 0..<384 { sums[index][column] += hidden[index - start][column] }
                counts[index] += 1
            }
        }
        let vectors = sums.enumerated().map { index, row in
            row.map { Double($0) / Double(counts[index]) }
        }
        return Document(offsets: encoding.offsets, vectors: vectors)
    }

    func last2(text: String, spans: [Range<Int>]) throws -> [[Float]] {
        let scalars = Array(text.unicodeScalars)
        let model = try runner.model(function: "teacher_last2")
        return try spans.map { range in
            try Task.checkCancellation()
            let left = max(0, range.lowerBound - 160)
            let right = min(scalars.count, range.upperBound + 160)
            let context = String(String.UnicodeScalarView(scalars[left..<right]))
            let normalized = String(String.UnicodeScalarView(context.unicodeScalars.map { scalar in
                scalar.properties.generalCategory == .control
                    && scalar != "\n" && scalar != "\r" && scalar != "\t" ? " " : scalar
            }))
            let encoding = try tokenizer.encode(normalized)
            let ids = Array(encoding.ids.prefix(510))
            let offsets = Array(encoding.offsets.prefix(510))
            let local = (range.lowerBound - left)..<(range.upperBound - left)
            let selected = offsets.indices.filter { offsets[$0].overlaps(local) }
            let ledger = Document(offsets: offsets, vectors: [])
            try ledger.validateCoverage(text: normalized, range: local)
            guard !selected.isEmpty else { throw R117RuntimeError.uncoveredSource }
            let hidden = try predict(model: model, ids: [0] + ids + [2])
            var pooled = Array(repeating: Float(0), count: 384)
            for index in selected {
                for column in 0..<384 { pooled[column] += hidden[index + 1][column] }
            }
            return pooled.map { $0 / Float(selected.count) }
        }
    }

    func predict(model: MLModel, ids: [Int]) throws -> [[Float]] {
        let length = max(2, ids.count)
        let shape = [NSNumber(value: 1), NSNumber(value: length)]
        let input = try MLMultiArray(shape: shape, dataType: .int32)
        let mask = try MLMultiArray(shape: shape, dataType: .int32)
        for index in 0..<length {
            input[index] = NSNumber(value: index < ids.count ? ids[index] : 1)
            mask[index] = NSNumber(value: index < ids.count ? 1 : 0)
        }
        let provider = try MLDictionaryFeatureProvider(dictionary: [
            "ids": input, "attention_mask": mask
        ])
        let prediction = try model.prediction(from: provider)
        guard let output = prediction.featureValue(for: "token_embeddings")?.multiArrayValue,
              output.count == length * 384 else { throw R117RuntimeError.invalidModelOutput }
        return (0..<ids.count).map { row in
            (0..<384).map { output[row * 384 + $0].floatValue }
        }
    }

    static func relative(_ candidate: [Float], context: [Float]) -> [Float] {
        let product = zip(candidate, context).map(*)
        let dot = product.reduce(Float(0), +)
        let left = sqrt(candidate.map { $0 * $0 }.reduce(Float(0), +))
        let right = sqrt(context.map { $0 * $0 }.reduce(Float(0), +))
        return candidate + product + [dot / (left * right + 1e-8)]
    }
}
