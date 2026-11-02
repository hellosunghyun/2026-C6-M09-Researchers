import CoreML
import Foundation
@testable import LabcordiOS
import XCTest

final class R117HeadBufferTests: XCTestCase {
    func testAllHeadFunctionsMatchScalarInputAndOutputAccess() throws {
        let directory = try XCTUnwrap(R117TermExtractor.resourceDirectory)
        let runner = try R117HeadRunner(resourceDirectory: directory)
        for function in ["r117_seed42", "teacher_window", "teacher_scope",
                         "teacher_purpose", "teacher_last2_head"] {
            let last2 = function == "teacher_last2_head"
            let width = last2 ? 384 : 769
            let inputName = last2 ? "pooled_features" : "features"
            let features = (0..<3).map { row in
                (0..<width).map { Float(($0 + row * 7) % 97 - 48) / 7 }
            }
            let input = try MLMultiArray(
                shape: [3, NSNumber(value: width)], dataType: .float32
            )
            for (row, values) in features.enumerated() {
                for (column, value) in values.enumerated() {
                    input[row * width + column] = NSNumber(value: value)
                }
            }
            let provider = try MLDictionaryFeatureProvider(dictionary: [inputName: input])
            let model = try runner.model(function: function)
            let predicted = try model.prediction(from: provider)
            let logits = try XCTUnwrap(predicted.featureValue(for: "logits")?.multiArrayValue)
            let expected = (0..<3).map { logits[$0].doubleValue }
            let actual = try runner.predictHead(
                function: function, features: features, inputName: inputName
            )
            XCTAssertEqual(actual, expected, function)
        }
    }

    func testInvalidFeatureShapesAndNonfiniteValuesAreRejected() throws {
        let directory = try XCTUnwrap(R117TermExtractor.resourceDirectory)
        let runner = try R117HeadRunner(resourceDirectory: directory)
        for features: [[Float]] in [[], [[]], [[1]], [Array(repeating: .nan, count: 769)]] {
            XCTAssertThrowsError(try runner.predictHead(
                function: "r117_seed42", features: features
            ))
        }
    }
}
