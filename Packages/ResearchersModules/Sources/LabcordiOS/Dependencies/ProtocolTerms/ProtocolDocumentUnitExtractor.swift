import Foundation

/// 상위 용어 후보에 들지 않은 측정 단위도 문서에 실제로 적힌 표기에서 보충합니다.
nonisolated enum ProtocolDocumentUnitExtractor {
    private static let atom = #"(?:°[CF]|℃|℉|°|%|R\.H\.?|RH|pH|OD(?:600)?|rpm|ppm|ppb|"#
        + #"㎖|㎕|㎛|㎜|㎝|㎞|㎟|㎠|㎡|㎢|㎣|㎤|㎥|㎎|㎏|㎐|㎑|㎒|㎓|㎩|㎪|㎫|"#
        + #"mmHg|cmH2O|(?:[fpnµμumcdkMGT]|da)?"#
        + #"(?:mol|mhos?|Pa|Hz|Da|IU|L|l|g|m|M|V|A|W|N|J|K|S)|"#
        + #"bar|atm|psi|bp|kb|nt|U|v/v|w/v|w/w|s|min|h)"#
    private static let power = #"(?:\^?[−-]?[1-9]|[¹²³⁴⁵⁶⁷⁸⁹]|[⁻⁺][¹²³⁴⁵⁶⁷⁸⁹])?"#
    private static let inversePower = #"(?:\^[−-][1-9]|[−-][1-9]|⁻[¹²³⁴⁵⁶⁷⁸⁹])"#
    private static let compound = atom + power
        + #"(?:[ \t]*(?:/|·|⋅)[ \t]*"# + atom + power
        + #"|[ \t]+"# + atom + inversePower + #")*"#
    private static let percent = #"%(?:[ \t]*(?:R\.H\.?|RH|"#
        + #"\([ \t]*(?:v/v|w/v|w/w)[ \t]*\)))?"#
    private static let expression = #"(?:[×x][ \t]*g|"# + compound + ")"
    private static let pattern = #"(?<![A-Za-zµμ])(?:"# + percent
        + #"(?![0-9?])|"# + expression + #"(?![A-Za-zµμ0-9?]))"#
    private static let regex = try? NSRegularExpression(pattern: pattern)
    private static let quantity = try? NSRegularExpression(
        pattern: #"[0-9]+(?:[.,][0-9]+)*(?:[eE][+−-]?[0-9]+)?[ \t]*\z"#
    )
    private static let identifier = try? NSRegularExpression(
        pattern: #"\b(?:method|cd-rom|protocol|figure|table|model|catalog|"#
            + #"batch|lot|sample|part|no)"#
            + #"[ \t.#:-]*[0-9]+(?:[.-][0-9]+)*[ \t]*\z"#, options: .caseInsensitive
    )
    private static let formulaSuffix = try? NSRegularExpression(
        pattern: #"^(?:\][ \t]*(?:[0-9]|[lo]\b)|-[lI][0o]\b)"#
    )
    private static let header = try? NSRegularExpression(
        pattern: #"(?:\b(?:units?|volume|mass|length|height|width|depth|concentration|"#
            + #"conductivity|conductance)|단위|부피|질량|길이|높이|너비|깊이|농도|전도도)"#
            + #"[ \t]*[:,=]?[ \t]*(?:[(\[][ \t]*)?$"#,
        options: .caseInsensitive
    )
    private static let specificHeaders = [
        "A": #"(?:\b(?:current|amperes?)|전류|암페어)"#,
        "N": #"(?:\b(?:normality|force)|노르말|힘|수직항력)"#,
        "K": #"(?:\b(?:temperature|kelvin)|온도|켈빈)"#,
        "S": #"(?:\b(?:conductance|conductivity|siemens)|전도도|컨덕턴스|지멘스)"#
    ].compactMapValues {
        try? NSRegularExpression(
            pattern: $0 + #"[ \t]*[:=]?[ \t]*(?:[(\[][ \t]*)?$"#,
            options: .caseInsensitive
        )
    }
    private static let measurementSymbols: Set<String> = [
        "pH", "RH", "R.H", "R.H.", "OD", "OD600", "rpm", "ppm", "ppb"
    ]
    private static let biologicalSuffix = try? NSRegularExpression(
        pattern: #"^[ \t]*(?:protein|proteasome|ribosomal|rRNA|단백질)"#,
        options: .caseInsensitive
    )
    private static let litreSymbol = try? NSRegularExpression(
        pattern: #"(?<![A-Za-zµμ])([fpnµμumcdkMGT]|da)?l(?![A-Za-zµμ])"#
    )
    private static let microPrefix = try? NSRegularExpression(
        pattern: #"(?<![A-Za-zµμ])u(?=(?:mol|mhos?|Pa|Hz|Da|IU|L|l|g|m|M|V|A|W|N|J|K|S)"#
            + #"(?![A-Za-zµμ]))"#
    )
    private static let durations: Set<String> = ["h", "min", "s"]
    private static let dimension = #"(?:길이|높이|거리|깊이|너비|폭|두께|"#
        + #"\b(?:length|height|distance|depth|width|thickness))"#
    private static let metrePrefix = try? NSRegularExpression(
        pattern: dimension + #"[ \t]*(?:(?:는|은|가|이|of|is|to|=|:|：)[ \t]*)?"#
            + #"(?:(?:약|about|approximately)[ \t]*)?"#
            + #"[+−-]?[0-9]+(?:[.,][0-9]+)?"#
            + #"(?:[ \t]*(?:~|〜|–|—|-|to)[ \t]*[0-9]+(?:[.,][0-9]+)?)?[ \t]*$"#,
        options: .caseInsensitive
    )
    private static let metreSuffix = try? NSRegularExpression(
        pattern: #"^[ \t]*(?:길이|높이|거리|깊이|너비|폭|두께|"#
            + #"(?:in[ \t]+)?(?:length|height|distance|depth|width|thickness|"#
            + #"long|high|deep|wide)\b)"#,
        options: .caseInsensitive
    )

    static func extract(from source: String) -> [String] {
        guard let regex else { return [] }
        var seen: Set<String> = []
        return regex.matches(in: source, range: NSRange(source.startIndex..., in: source))
            .compactMap { match in
                guard let range = Range(match.range, in: source) else { return nil }
                let unit = String(source[range])
                guard !durations.contains(unit), isMeasurement(unit, at: range, source: source),
                      seen.insert(key(unit)).inserted else { return nil }
                return unit
            }
    }

    static func supplement(
        _ terms: ProtocolExtractedTerms, from source: String
    ) -> ProtocolExtractedTerms {
        let measured = extract(from: source)
        let measuredKeys = Set(measured.map(key))
        var result = terms
        // 명확한 단위 표기만 옮기고 약품명·농도가 붙은 시약명 분류는 유지합니다.
        result.materials.removeAll { measuredKeys.contains(key($0)) }
        result.samples.removeAll { measuredKeys.contains(key($0)) }
        result.glossaryTerms.removeAll { measuredKeys.contains(key($0)) }
        var seen: Set<String> = []
        result.units = (terms.units + measured).filter { seen.insert(key($0)).inserted }
        return result
    }

    static func isUnit(_ value: String) -> Bool {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, let regex else { return false }
        let range = NSRange(value.startIndex..., in: value)
        guard let match = regex.firstMatch(in: value, range: range) else { return false }
        return match.range == range
    }

    /// 단독 m은 분과 미터가 겹치므로 명시적인 치수 맥락만 미터로 보충합니다.
    static func isMetre(at range: Range<String.Index>, in source: String) -> Bool {
        let prefix = String(source[..<range.lowerBound].suffix(64))
            .precomposedStringWithCompatibilityMapping
        let suffix = String(source[range.upperBound...].prefix(32))
        let previous = prefix.last { !$0.isWhitespace }
        let next = suffix.first { !$0.isWhitespace }
        if (previous == "(" && next == ")") || (previous == "[" && next == "]") {
            return true
        }
        return metrePrefix?.firstMatch(in: prefix,
                                       range: NSRange(prefix.startIndex..., in: prefix)) != nil
            || metreSuffix?.firstMatch(in: suffix,
                                       range: NSRange(suffix.startIndex..., in: suffix)) != nil
    }

    private static func isMeasurement(
        _ unit: String, at range: Range<String.Index>, source: String
    ) -> Bool {
        if unit == "m" { return isMetre(at: range, in: source) }
        if measurementSymbols.contains(unit) || unit.contains("%") || unit.contains("°")
            || unit.precomposedStringWithCompatibilityMapping != unit { return true }
        if unit.contains("/") || unit.contains("·") || unit.contains("⋅") { return true }
        let prefix = String(source[..<range.lowerBound].suffix(64))
        let suffix = String(source[range.upperBound...].prefix(32))
        if unit == "S", biologicalSuffix?.firstMatch(
            in: suffix, range: NSRange(suffix.startIndex..., in: suffix)
        ) != nil { return false }
        if formulaSuffix?.firstMatch(in: suffix,
                                     range: NSRange(suffix.startIndex..., in: suffix)) != nil {
            return false
        }
        if hasQuantity(prefix) { return true }
        if let specific = specificHeaders[unit] {
            return specific.firstMatch(in: prefix,
                                       range: NSRange(prefix.startIndex..., in: prefix)) != nil
        }
        return isHeader(prefix: prefix, suffix: suffix)
    }

    private static func hasQuantity(_ prefix: String) -> Bool {
        let fullRange = NSRange(prefix.startIndex..., in: prefix)
        guard let match = quantity?.firstMatch(in: prefix, range: fullRange),
              let range = Range(match.range, in: prefix) else { return false }
        if identifier?.firstMatch(in: prefix, range: fullRange) != nil { return false }
        if let previous = prefix[..<range.lowerBound].last {
            if previous == ")" || previous == "]" { return false }
            if let scalar = previous.unicodeScalars.first,
               (65...90).contains(scalar.value) || (97...122).contains(scalar.value) {
                return false
            }
        }
        return true
    }

    private static func isHeader(prefix: String, suffix: String) -> Bool {
        let previous = prefix.last { !$0.isWhitespace }
        let next = suffix.first { !$0.isWhitespace }
        if (previous == "(" && next == ")") || (previous == "[" && next == "]") {
            return true
        }
        if previous == ":" || previous == "：" { return true }
        let linePrefix = prefix.split(separator: "\n", omittingEmptySubsequences: false).last ?? ""
        let lineSuffix = suffix.split(separator: "\n", omittingEmptySubsequences: false)
            .first ?? ""
        if linePrefix.trimmingCharacters(in: .whitespaces).isEmpty,
           lineSuffix.trimmingCharacters(in: .whitespaces).isEmpty { return true }
        return header?.firstMatch(in: prefix,
                                  range: NSRange(prefix.startIndex..., in: prefix)) != nil
    }

    static func key(_ value: String) -> String {
        var key = value.precomposedStringWithCompatibilityMapping
            .replacingOccurrences(of: "µ", with: "μ")
        // 낱말 내부의 l은 건드리지 않고 단위 성분의 l·u 표기만 통일합니다.
        for (expression, replacement) in [(litreSymbol, "$1L"), (microPrefix, "μ")] {
            if let expression {
                key = expression.stringByReplacingMatches(
                    in: key, range: NSRange(key.startIndex..., in: key),
                    withTemplate: replacement
                )
            }
        }
        return key
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\t", with: "")
    }
}
