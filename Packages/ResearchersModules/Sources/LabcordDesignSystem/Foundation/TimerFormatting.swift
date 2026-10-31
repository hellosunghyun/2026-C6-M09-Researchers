import Foundation

/// 설정 시간의 앞부분과 마지막 단위를 서로 다른 글자 스타일로 표시할 때 사용합니다.
public struct TimerDurationComponents: Equatable, Sendable {
    public let value: String
    public let unit: String

    public var text: String { value + unit }
}

/// 설정 시간을 단위별 한국어 문구로 표시하는 Foundation FormatStyle입니다.
///
/// 입력 범위 검증은 호출부가 소유하며, 이 스타일은 값을 저장하거나 보정하지 않습니다.
/// 초 미만은 표시하지 않으며 단위 문자열은 현재 원본의 한국어를 사용합니다.
public struct TimerDurationFormatStyle: FormatStyle, Sendable {
    public init() { }

    public func format(_ value: Duration) -> String {
        components(value).text
    }

    public func components(_ duration: Duration) -> TimerDurationComponents {
        let total = duration.components.seconds
        let magnitude = total.magnitude
        let hours = magnitude / 3_600
        let minutes = magnitude % 3_600 / 60
        let seconds = magnitude % 60
        let sign = total < 0 ? "-" : ""
        let parts: [(UInt64, String)] = [
            (hours, "시간"), (minutes, "분"), (seconds, "초")
        ].filter { $0.0 > 0 }
        let last = parts.last ?? (0, "초")
        let prefix = parts.dropLast().map { "\($0.0)\($0.1)" }
        let value = (prefix + [String(last.0)]).joined(separator: " ")
        return TimerDurationComponents(value: sign + value, unit: last.1)
    }
}

/// 남은 시간을 호출부가 선택한 고정 자릿수로 표시하는 시계 형식입니다.
public struct TimerClockFormatStyle: FormatStyle, Sendable {
    public let includesHours: Bool

    public init(includesHours: Bool = false) {
        self.includesHours = includesHours
    }

    public func format(_ duration: Duration) -> String {
        let wholeSeconds = Duration.seconds(duration.components.seconds)
        if includesHours {
            return wholeSeconds.formatted(
                .time(pattern: .hourMinuteSecond(padHourToLength: 2))
            )
        }
        return wholeSeconds.formatted(.time(pattern: .minuteSecond(padMinuteToLength: 2)))
    }
}

public extension FormatStyle where Self == TimerDurationFormatStyle {
    static var labcordDuration: Self { Self() }
}

public extension FormatStyle where Self == TimerClockFormatStyle {
    static func labcordClock(includesHours: Bool = false) -> Self {
        Self(includesHours: includesHours)
    }
}
