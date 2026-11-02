import Foundation

/// Extracts explicit durations in text order. Ambiguous formats are left for editing.
nonisolated public enum ProtocolTimerExtractor {
    private static let units =
        "(?:hours?|hrs?|hr|h|minutes?|mins?|min|m|seconds?|secs?|sec|s|시간|분|초)"
    private static let number = "(?:[0-9]{1,3}(?:,[0-9]{3})+|[0-9]+)(?:\\.[0-9]+)?"
    private static let rangePattern =
        "(?<![0-9.,:\\-])(\(number))\\s*(?:~|–|—|-|\\bto\\b)" +
        "\\s*(\(number))\\s*(\(units))(?![A-Za-z]|의)"
    private static let itemPattern =
        "(?<![0-9.,:])(\(number))\\s*(\(units))(?![A-Za-z]|의)"
    private static let combinedPattern =
        "\(itemPattern)(?:\\s+\(itemPattern)){0,2}"
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
            let value = String(text[range])
            return value.contains(".") && value.range(of: "[a-zA-Z가-힣]\\s*[~–—-]",
                                                       options: .regularExpression) != nil
        }
        let ranges = rangeRegex.matches(in: text, range: fullRange).filter { match in
            !excluded.contains { NSIntersectionRange($0.range, match.range).length > 0 }
        }
        let clocks = clockRegex.matches(in: text, range: fullRange).filter { match in
            !isClockTime(text, range: match.range)
        }
        let protected = (ranges + excluded + clockRegex.matches(in: text, range: fullRange))
            .map(\.range).sorted { $0.location < $1.location }
        var gaps: [NSRange] = []
        var offset = 0
        for blocked in protected {
            if blocked.location > offset {
                gaps.append(NSRange(location: offset, length: blocked.location - offset))
            }
            offset = max(offset, NSMaxRange(blocked))
        }
        if offset < fullRange.length {
            gaps.append(NSRange(location: offset, length: fullRange.length - offset))
        }
        let singles = gaps.flatMap { combinedRegex.matches(in: text, range: $0) }
            .filter { !isFalsePositive(text, range: $0.range) }
        let matches = (ranges.map { ($0, 1) } + singles.map { ($0, 0) } + clocks.map { ($0, 2) })
            .sorted { $0.0.range.location < $1.0.range.location }
        return matches.flatMap { match, kind in
            values(text: text, match: match, kind: kind, itemRegex: itemRegex)
        }
    }

    private static func isClockTime(_ text: String, range: NSRange) -> Bool {
        let source = text as NSString
        let prefixStart = max(0, range.location - 24)
        let prefixRange = NSRange(location: prefixStart, length: range.location - prefixStart)
        let prefix = source.substring(with: prefixRange)
        let suffixStart = NSMaxRange(range)
        let suffixRange = NSRange(
            location: suffixStart, length: min(16, source.length - suffixStart)
        )
        let suffix = source.substring(with: suffixRange)
        return prefix.range(of: "(?:오전|오후|[0-9]{4}-[0-9]{2}-[0-9]{2}[ T])\\s*$",
                            options: [.regularExpression, .caseInsensitive]) != nil
            || suffix.range(of: "^(?:\\.[0-9]+|\\s*(?:AM|PM|기록|시각))",
                            options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func isFalsePositive(_ text: String, range: NSRange) -> Bool {
        let source = text as NSString
        let start = NSMaxRange(range)
        if range.location > 0,
           source.substring(with: NSRange(location: range.location - 1, length: 1)) == "-" {
            let before = source.substring(to: range.location - 1)
            let isRange = before.range(
                of: "(?:시간|분|초|hours?|hrs?|minutes?|mins?|seconds?|secs?|[hms])\\s*$",
                options: [.regularExpression, .caseInsensitive]
            ) != nil
            if !isRange { return true }
        }
        let suffixRange = NSRange(location: start, length: min(20, source.length - start))
        let suffix = source.substring(with: suffixRange)
        return suffix.range(of: "^\\s*(?:protein|proteasome|ribosomal|rRNA|단백질)",
                            options: [.regularExpression, .caseInsensitive]) != nil
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
            guard let first = string(in: text, match: match, group: 1),
                  let last = string(in: text, match: match, group: 2),
                  let unit = string(in: text, match: match, group: 3) else { return [] }
            return [seconds(first, unit: unit), seconds(last, unit: unit)]
                .compactMap { $0 }.filter { $0 > 0 }
        }
        let parts = itemRegex.matches(in: text, range: match.range)
        let components: [(Int, Int)] = parts.compactMap { part in
            guard let value = string(in: text, match: part, group: 1),
                  let unit = string(in: text, match: part, group: 2),
                  let total = seconds(value, unit: unit),
                  let scale = multiplier(for: unit) else { return nil }
            return (total, scale)
        }
        guard components.count == parts.count else { return [] }
        let ordered = zip(components, components.dropFirst()).allSatisfy { $0.0.1 > $0.1.1 }
        if ordered {
            var total = 0
            for (part, _) in components {
                let (sum, overflow) = total.addingReportingOverflow(part)
                guard !overflow else { return [] }
                total = sum
            }
            return total > 0 ? [total] : []
        }
        return components.map(\.0).filter { $0 > 0 }
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

    private static func seconds(_ value: String, unit: String) -> Int? {
        guard let scale = multiplier(for: unit),
              let number = Decimal(string: value.replacingOccurrences(of: ",", with: ""),
                                   locale: Locale(identifier: "en_US_POSIX")) else { return nil }
        let product = NSDecimalNumber(decimal: number)
            .multiplying(by: NSDecimalNumber(value: scale))
        let rounded = product.rounding(accordingToBehavior: NSDecimalNumberHandler(
            roundingMode: .plain, scale: 0, raiseOnExactness: false, raiseOnOverflow: false,
            raiseOnUnderflow: false, raiseOnDivideByZero: false
        ))
        guard product == rounded, product.compare(NSDecimalNumber.zero) != .orderedAscending,
              product.compare(NSDecimalNumber(value: Int.max)) != .orderedDescending else {
            return nil
        }
        return product.intValue
    }

    private static func multiplier(for unit: String) -> Int? {
        switch unit.lowercased() {
        case "시간", "h", "hr", "hrs", "hour", "hours": 3_600
        case "분", "m", "min", "mins", "minute", "minutes": 60
        case "초", "s", "sec", "secs", "second", "seconds": 1
        default: nil
        }
    }
}
