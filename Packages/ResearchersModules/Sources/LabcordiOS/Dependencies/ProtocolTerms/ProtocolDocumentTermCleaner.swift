import Foundation
import OmniParser

/// 원문 scalar 좌표와 파서 블록을 대조해 서로 다른 요소를 잇는 후보를 제거합니다.
nonisolated enum ProtocolDocumentTermCleaner {
    enum Error: Swift.Error { case inconsistentDocument }

    private struct Candidate {
        let text: String
        let ranges: [Range<Int>]
    }

    static func clean(_ terms: [String], document: DocumentParseResult) throws -> [String] {
        let ranges = blockRanges(document)
        guard ranges.text == document.fullText else { throw Error.inconsistentDocument }
        let source = document.fullText
        let scalars = Array(source.unicodeScalars)
        let surfaces = terms.flatMap { term -> [String] in
            let isContained = occurrences(of: term, in: source).contains { occurrence in
                ranges.blocks.contains { $0.lowerBound <= occurrence.lowerBound
                    && occurrence.upperBound <= $0.upperBound }
            }
            guard isContained, !crossesListItem(term), !crossesReactions(term) else { return [] }
            return splitList(term)
        }
        let candidates: [Candidate] = surfaces.compactMap { surface in
            guard !surface.isEmpty, !isTruncatedSymbol(surface),
                  hasBalancedDelimiters(surface) else { return nil }
            let valid = occurrences(of: surface, in: source).filter { occurrence in
                ranges.blocks.contains { $0.lowerBound <= occurrence.lowerBound
                    && occurrence.upperBound <= $0.upperBound }
            }
            guard !valid.isEmpty else { return nil }
            return Candidate(text: surface, ranges: valid)
        }
        let complete = candidates.filter { !isBrokenKoreanEnding($0, source: source) }
        let expanded = complete.map { candidate in
            expandComposite(candidate, source: source, blocks: ranges.blocks)
        }
        let canonical = expanded.filter { !isInflected($0, candidates: expanded) }
        var seen = Set<String>()
        return Array(canonical.filter { candidate in
            guard seen.insert(candidate.text).inserted else { return false }
            return !candidate.ranges.allSatisfy { range in
                isFragment(range, scalars: scalars) && canonical.contains { other in
                    other.text != candidate.text && other.ranges.contains {
                        $0.lowerBound <= range.lowerBound && $0.upperBound >= range.upperBound
                    }
                }
            }
        }.map(\.text).prefix(50))
    }

    private static func expandComposite(
        _ candidate: Candidate, source: String, blocks: [Range<Int>]
    ) -> Candidate {
        guard candidate.text.contains("_") else { return candidate }
        let pattern = "[\\p{L}\\p{N}]+\\([^()\\n]*_[^()\\n]*\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return candidate }
        let matches = regex.matches(in: source, range: NSRange(source.startIndex..., in: source))
        let enclosing: [(String, Range<Int>)] = matches.compactMap { match in
            guard let range = Range(match.range, in: source),
                  let start = range.lowerBound.samePosition(in: source.unicodeScalars),
                  let end = range.upperBound.samePosition(in: source.unicodeScalars) else {
                return nil
            }
            let scalarRange = source.unicodeScalars.distance(
                from: source.unicodeScalars.startIndex, to: start
            )..<source.unicodeScalars.distance(from: source.unicodeScalars.startIndex, to: end)
            guard blocks.contains(where: { $0.lowerBound <= scalarRange.lowerBound
                && scalarRange.upperBound <= $0.upperBound }) else { return nil }
            return (String(source[range]), scalarRange)
        }
        let expansions = candidate.ranges.map { range -> String? in
            let valid = enclosing.filter { $0.1.lowerBound < range.lowerBound
                && $0.1.upperBound > range.upperBound }
            guard valid.count == 1 else { return nil }
            return valid[0].0
        }
        guard let first = expansions.first ?? nil,
              expansions.allSatisfy({ $0 == first }) else { return candidate }
        return Candidate(text: first, ranges: occurrences(of: first, in: source))
    }

    private static func splitList(_ text: String) -> [String] {
        var parts: [String] = []
        var start = text.startIndex
        var depth = 0
        for index in text.indices {
            let character = text[index]
            if character == "(" || character == "（" { depth += 1 }
            if character == ")" || character == "）" { depth = max(0, depth - 1) }
            guard depth == 0, character == ";" || character == "," else { continue }
            if character == "," && isChemicalComma(text, at: index) { continue }
            let piece = text[start..<index].trimmingCharacters(in: .whitespacesAndNewlines)
            if !piece.isEmpty { parts.append(piece) }
            start = text.index(after: index)
        }
        let piece = text[start...].trimmingCharacters(in: .whitespacesAndNewlines)
        if !piece.isEmpty { parts.append(piece) }
        return parts
    }

    private static func isChemicalComma(_ text: String, at index: String.Index) -> Bool {
        let left = String(text[..<index])
        let right = String(text[text.index(after: index)...])
        let locantLeft = left.range(of: "(?:^|[^A-Za-z0-9])[0-9]+$|(?:^|[^A-Za-z])N$",
                                    options: .regularExpression) != nil
        let locantRight = right.range(of: "^\\s*(?:[0-9]+|N)\\s*[-,]",
                                      options: .regularExpression) != nil
        return locantLeft && locantRight
    }

    private static func crossesReactions(_ term: String) -> Bool {
        let lines = term.components(separatedBy: .newlines)
        return lines.filter { $0.contains("→") || $0.contains("->") || $0.contains("⇌") }.count > 1
    }

    private static func blockRanges(
        _ document: DocumentParseResult
    ) -> (text: String, blocks: [Range<Int>]) {
        var text = ""
        var blocks: [Range<Int>] = []
        var offset = 0
        for block in document.blocks where !block.text.isEmpty
                && block.kind != .table && block.kind != .image {
            if !text.isEmpty { text.append("\n"); offset += 1 }
            let length = block.text.unicodeScalars.count
            blocks.append(offset..<(offset + length))
            text.append(block.text)
            offset += length
        }
        return (text, blocks)
    }

    private static func occurrences(of term: String, in source: String) -> [Range<Int>] {
        var result: [Range<Int>] = []
        var offset = source.startIndex
        while offset < source.endIndex,
              let range = source.range(of: term, range: offset..<source.endIndex) {
            let scalars = source.unicodeScalars
            guard let left = range.lowerBound.samePosition(in: scalars),
                  let right = range.upperBound.samePosition(in: scalars) else { break }
            let start = scalars.distance(from: scalars.startIndex, to: left)
            let end = scalars.distance(from: scalars.startIndex, to: right)
            result.append(start..<end)
            offset = source.index(after: range.lowerBound)
        }
        return result
    }

    private static func isFragment(_ range: Range<Int>, scalars: [Unicode.Scalar]) -> Bool {
        func isWord(_ scalar: Unicode.Scalar) -> Bool {
            CharacterSet.letters.contains(scalar) || CharacterSet.decimalDigits.contains(scalar)
        }
        let beginsWithParenthesis = scalars[range.lowerBound] == "("
            || scalars[range.lowerBound] == "（"
        return (range.lowerBound > 0 && isWord(scalars[range.lowerBound - 1])
                && (isWord(scalars[range.lowerBound]) || beginsWithParenthesis))
            || (range.upperBound < scalars.count && isWord(scalars[range.upperBound - 1])
                && isWord(scalars[range.upperBound]))
    }

    private static func isInflected(_ candidate: Candidate, candidates: [Candidate]) -> Bool {
        let particles = ["은", "는", "이", "가", "을", "를", "의", "에", "에서", "으로", "로"]
        return candidates.contains { other in
            other.text != candidate.text && other.text.count >= 2
                && particles.contains { candidate.text == other.text + $0 }
        }
    }

    private static func isBrokenKoreanEnding(_ candidate: Candidate, source: String) -> Bool {
        let words = candidate.text.split { $0.isWhitespace }
        guard words.count > 1, let last = words.last, last.count == 1,
              let value = last.unicodeScalars.first, (0xAC00...0xD7A3).contains(value.value)
        else { return false }
        let scalars = Array(source.unicodeScalars)
        let particles = ["은", "는", "이", "가", "을", "를", "의", "에", "에서", "으로", "로"]
        return candidate.ranges.allSatisfy { range in
            let suffix = scalars[range.upperBound...].prefix {
                (0xAC00...0xD7A3).contains($0.value)
            }
            let text = String(String.UnicodeScalarView(suffix))
            return !text.isEmpty && !particles.contains(text)
        }
    }

    private static func hasBalancedDelimiters(_ text: String) -> Bool {
        let pairs: [Character: Character] = [")": "(", "）": "（", "]": "[", "}": "{"]
        let opening = Set(pairs.values)
        var stack: [Character] = []
        for character in text {
            if opening.contains(character) {
                stack.append(character)
            } else if let expected = pairs[character], stack.popLast() != expected {
                return false
            }
        }
        return stack.isEmpty
    }

    private static func isTruncatedSymbol(_ term: String) -> Bool {
        term.range(of: "^[A-Za-z]\\.$|^[A-Za-z]{1,3}\\?$", options: .regularExpression) != nil
    }

    private static func crossesListItem(_ term: String) -> Bool {
        term.range(of: "\\n\\s*(?:[0-9]+[.)]|[-•])\\s", options: .regularExpression) != nil
    }
}
