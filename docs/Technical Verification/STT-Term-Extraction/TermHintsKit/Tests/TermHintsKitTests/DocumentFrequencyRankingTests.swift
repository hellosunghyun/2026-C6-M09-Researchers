@testable import TermHintsKit
import XCTest

final class DocumentFrequencyRankingTests: XCTestCase {
  func testEmptyAndZeroLimit() throws {
    XCTAssertTrue(try DocumentFrequencyRanking.hints(
      candidates: [], fusion: [], text: "", limit: 50).isEmpty)
    XCTAssertTrue(try DocumentFrequencyRanking.hints(
      candidates: [], fusion: [], text: "PCR", limit: 0).isEmpty)
  }

  func testDuplicateSpansAndUnicodeOffsets() throws {
    let text = "PCR PCR 교정 Aβ 🧪"
    let candidates = [
      CachedCandidate(start: 0, end: 3, score: 0.8, admitted: true, norm: "pcr"),
      CachedCandidate(start: 4, end: 7, score: 0.8, admitted: true, norm: "pcr"),
      CachedCandidate(start: 8, end: 10, score: 0.85, admitted: true, norm: "교정"),
      CachedCandidate(start: 11, end: 13, score: 0.8, admitted: true, norm: "aβ")
    ]
    let fusion = [
      RankingHint(text: "PCR", start: 0, end: 3, score: 0.8),
      RankingHint(text: "교정", start: 8, end: 10, score: 0.85),
      RankingHint(text: "Aβ", start: 11, end: 13, score: 0.8)
    ]
    let expected = try DocumentFrequencyRanking.hints(
      candidates: candidates, fusion: fusion, text: text, limit: 50)
    let repeated = try DocumentFrequencyRanking.hints(
      candidates: Array(repeating: candidates[0], count: 25) + candidates,
      fusion: fusion, text: text, limit: 50)
    XCTAssertEqual(expected, repeated)
    XCTAssertEqual(expected.first?.text, "PCR")
    XCTAssertEqual(Set(expected.map(\.text)), Set(fusion.map(\.text)))
    let scalars = Array(text.unicodeScalars)
    for hint in expected {
      XCTAssertEqual(String(String.UnicodeScalarView(scalars[hint.start..<hint.end])), hint.text)
      XCTAssertTrue(fusion.contains(hint))
    }
  }

  func testDecomposedHangulMatchesSurfaceRule() throws {
    let decomposed = "\u{1100}\u{1161}"
    let text = decomposed + " PCR"
    let fusion = [
      RankingHint(text: decomposed, start: 0, end: 2, score: 0.81),
      RankingHint(text: "PCR", start: 3, end: 6, score: 0.8)
    ]
    let candidates = [
      CachedCandidate(start: 0, end: 2, score: 0.81, admitted: true, norm: "가"),
      CachedCandidate(start: 3, end: 6, score: 0.8, admitted: true, norm: "pcr")
    ]
    let ranked = try DocumentFrequencyRanking.hints(
      candidates: candidates, fusion: fusion, text: text, limit: 50)
    XCTAssertEqual(ranked.first?.start, 0)
    XCTAssertEqual(ranked.first?.end, 2)
  }

  func testKoreanCharacterCandidatesArePreserved() {
    let text = "대한민국"
    let scalars = Array(text.unicodeScalars)
    let spans = TermHintDecoder.genTagged(TagGenerationInput(
      text: scalars, start: 0, end: scalars.count, language: "ko",
      maxN: 1, depth: 0, emitRoot: false, scorer: nil))
    let characterSpans = spans.filter { $0.kind == "charngram" }
    let surfaces = characterSpans.map {
      String(String.UnicodeScalarView(scalars[$0.start..<$0.end]))
    }
    XCTAssertTrue(surfaces.contains("대한"))
    XCTAssertTrue(surfaces.contains("민국"))
  }

  func testOnlyFirst75CanChangeAndTop100IsPreserved() throws {
    let words = (0..<100).map { "term\($0)" }
    let text = words.joined(separator: " ")
    var start = 0
    var candidates: [CachedCandidate] = []
    var fusion: [RankingHint] = []
    for (index, word) in words.enumerated() {
      let end = start + word.unicodeScalars.count
      let score = Double(index) / 100
      candidates.append(CachedCandidate(
        start: start, end: end, score: score, admitted: true, norm: word))
      fusion.append(RankingHint(text: word, start: start, end: end, score: score))
      start = end + 1
    }
    let ranked = try DocumentFrequencyRanking.hints(
      candidates: candidates, fusion: fusion, text: text, limit: 100)
    XCTAssertEqual(ranked.first?.text, "term74")
    XCTAssertEqual(Array(ranked.dropFirst(75)), Array(fusion.dropFirst(75)))
    XCTAssertEqual(Set(ranked.map(\.text)), Set(fusion.map(\.text)))
    XCTAssertEqual(ranked.count, 100)
  }
}
