import Foundation

/// Extracts explicit integer durations in text order. Ambiguous formats are left for editing.
nonisolated public enum ProtocolTimerExtractor {
    private static let units =
        "(?:hours?|hrs?|hr|h|minutes?|mins?|min|seconds?|secs?|sec|s|시간|분|초)"
    private static let rangePattern =
        "(?<![0-9.,:])([0-9]+)\\s*(?:~|–|—|-|\\bto\\b)\\s*([0-9]+)\\s*(\(units))(?![A-Za-z])"
    private static let itemPattern =
        "(?<![0-9.,:])([0-9]+)\\s*(\(units))(?![A-Za-z])"
    private static let combinedPattern =
        "\(itemPattern)(?:\\s*(?:,|and)?\\s*\(itemPattern)){0,2}"
    private static let clockPattern =
        "(?<![0-9:])([0-9]{1,3}):([0-5][0-9]):([0-5][0-9])(?![0-9:])"
    private static let decimalRangePattern =
        "(?<![0-9.])[0-9]+(?:\\.[0-9]+)?\\s*\(units)?\\s*" +
        "(?:~|–|—|-|\\bto\\b)\\s*[0-9]+(?:\\.[0-9]+)?\\s*\(units)(?![A-Za-z])"

    public static func extract(from text: String) -> [Int] {
        guard let rangeRegex = try? NSRegularExpression(
                pattern: rangePattern, options: .caseInsensitive
              ),
              let itemRegex = try? NSRegularExpression(
                pattern: itemPattern, options: .caseInsensitive
              ),
              let combinedRegex = try? NSRegularExpression(
                pattern: combinedPattern, options: .caseInsensitive
              ),
              let clockRegex = try? NSRegularExpression(pattern: clockPattern),
              let decimalRangeRegex = try? NSRegularExpression(
                pattern: decimalRangePattern, options: .caseInsensitive
              ) else { return [] }

        let fullRange = NSRange(text.startIndex..., in: text)
        let excluded = decimalRangeRegex.matches(in: text, range: fullRange).filter { match in
            guard let range = Range(match.range, in: text) else { return false }
            return text[range].contains(".")
        }
        let ranges = rangeRegex.matches(in: text, range: fullRange).filter { match in
            !excluded.contains { NSIntersectionRange($0.range, match.range).length > 0 }
        }
        let clocks = clockRegex.matches(in: text, range: fullRange)
        let singles = combinedRegex.matches(in: text, range: fullRange)
            .filter { match in
                !(ranges + excluded + clocks).contains {
                    NSIntersectionRange($0.range, match.range).length > 0
                }
            }
        let matches = (ranges.map { ($0, 1) } + singles.map { ($0, 0) } + clocks.map { ($0, 2) })
            .sorted { $0.0.range.location < $1.0.range.location }
        return matches.flatMap { match, kind in
            values(text: text, match: match, kind: kind, itemRegex: itemRegex)
        }
    }

    private static func values(
        text: String, match: NSTextCheckingResult, kind: Int, itemRegex: NSRegularExpression
    ) -> [Int] {
        if kind == 2 {
            guard let hours = integer(in: text, match: match, group: 1),
                  let minutes = integer(in: text, match: match, group: 2),
                  let seconds = integer(in: text, match: match, group: 3) else { return [] }
            let total = hours * 3_600 + minutes * 60 + seconds
            return total > 0 ? [total] : []
        }
        if kind == 1 {
            guard let first = integer(in: text, match: match, group: 1),
                  let last = integer(in: text, match: match, group: 2),
                  let unit = string(in: text, match: match, group: 3) else { return [] }
            return [seconds(first, unit: unit), seconds(last, unit: unit)].compactMap { $0 }
        }
        let parts = itemRegex.matches(in: text, range: match.range)
        let components: [(Int, Int)] = parts.compactMap { part in
            guard let value = integer(in: text, match: part, group: 1),
                  let unit = string(in: text, match: part, group: 2),
                  let scale = multiplier(for: unit) else { return nil }
            return (value, scale)
        }
        guard components.count == parts.count else { return [] }
        let ordered = zip(components, components.dropFirst()).allSatisfy { $0.0.1 > $0.1.1 }
        if ordered {
            var total = 0
            for (value, scale) in components {
                let (part, multiplyOverflow) = value.multipliedReportingOverflow(by: scale)
                let (sum, addOverflow) = total.addingReportingOverflow(part)
                guard !multiplyOverflow, !addOverflow else { return [] }
                total = sum
            }
            return total > 0 ? [total] : []
        }
        return components.compactMap { value, scale in
            let (result, overflow) = value.multipliedReportingOverflow(by: scale)
            return !overflow && result > 0 ? result : nil
        }
    }

    private static func integer(
        in text: String, match: NSTextCheckingResult, group: Int
    ) -> Int? {
        string(in: text, match: match, group: group).flatMap(Int.init)
    }

    private static func string(
        in text: String, match: NSTextCheckingResult, group: Int
    ) -> String? {
        guard let range = Range(match.range(at: group), in: text) else { return nil }
        return String(text[range])
    }

    private static func seconds(_ value: Int, unit: String) -> Int? {
        guard let scale = multiplier(for: unit) else { return nil }
        let (result, overflow) = value.multipliedReportingOverflow(by: scale)
        return !overflow && result > 0 ? result : nil
    }

    private static func multiplier(for unit: String) -> Int? {
        switch unit.lowercased() {
        case "시간", "h", "hr", "hrs", "hour", "hours": 3_600
        case "분", "min", "mins", "minute", "minutes": 60
        case "초", "s", "sec", "secs", "second", "seconds": 1
        default: nil
        }
    }
}
