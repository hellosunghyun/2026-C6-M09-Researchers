import Foundation

/// 상위 용어 후보에 들지 않은 측정 단위도 문서에 실제로 적힌 표기에서 보충합니다.
nonisolated enum ProtocolDocumentUnitExtractor {
    private static let atom = #"(?:°[CF]|℃|℉|°|%|R\.H\.?|RH|pH|OD(?:600)?|rpm|ppm|ppb|"#
        + #"㎖|㎕|㎛|㎜|㎝|㎞|㎟|㎠|㎡|㎢|㎣|㎤|㎥|㎎|㎏|㎐|㎑|㎒|㎓|㎩|㎪|㎫|"#
        + #"mmHg|cmH2O|(?:[fpnµμumcdkMGT]|da)?(?:mol|Pa|Hz|Da|IU|L|l|g|m|M|V|A|W|N|J|K)|"#
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
        pattern: #"(?:[0-9]+(?:[.,][0-9]+)?)[ \t]*$"#
    )
    private static let durations: Set<String> = ["h", "min", "s"]

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

    private static func isMeasurement(
        _ unit: String, at range: Range<String.Index>, source: String
    ) -> Bool {
        guard unit.count == 1 else { return true }
        if unit == "%" || unit == "℃" || unit == "℉" { return true }
        if unit.precomposedStringWithCompatibilityMapping != unit { return true }
        let prefix = String(source[..<range.lowerBound].suffix(24))
        if quantity?.firstMatch(in: prefix,
                                range: NSRange(prefix.startIndex..., in: prefix)) != nil {
            return true
        }
        let previous = prefix.last { !$0.isWhitespace }
        return previous == "(" || previous == "[" || previous == ":" || previous == "："
    }

    private static func key(_ value: String) -> String {
        value.precomposedStringWithCompatibilityMapping
            .replacingOccurrences(of: "µ", with: "μ")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\t", with: "")
    }
}
