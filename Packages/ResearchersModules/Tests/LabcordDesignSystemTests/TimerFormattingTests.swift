import Foundation
import Testing

@testable import LabcordDesignSystem

@Suite("타이머 표시")
struct TimerFormattingTests {
    @Test("설정 시간을 단위별 한국어 문구로 표시한다")
    func formatsCompoundUnits() {
        let examples: [(Int64, String)] = [
            (0, "0초"), (5, "5초"), (30, "30초"),
            (300, "5분"), (3_540, "59분"), (309, "5분 9초"),
            (3_599, "59분 59초"), (18_000, "5시간"), (82_800, "23시간"),
            (8_160, "2시간 16분"), (7_205, "2시간 5초"),
            (18_180, "5시간 3분"), (86_340, "23시간 59분"),
            (18_189, "5시간 3분 9초"), (86_399, "23시간 59분 59초")
        ]
        for (seconds, expected) in examples {
            #expect(TimerDurationFormatStyle().format(.seconds(seconds)) == expected)
        }
    }

    @Test("복합 시간의 앞부분과 마지막 단위를 별도 스타일로 표시할 수 있다")
    func separatesValueAndUnit() {
        let result = TimerDurationFormatStyle().components(.seconds(18_189))
        #expect(result.value == "5시간 3분 9")
        #expect(result.unit == "초")
        #expect(result.text == "5시간 3분 9초")
    }

    @Test("남은 시간이 줄어도 호출부가 선택한 시계 자릿수를 유지한다")
    func maintainsClockFormat() {
        let hours = TimerClockFormatStyle(includesHours: true)
        #expect(hours.format(.seconds(3_605)) == "01:00:05")
        #expect(hours.format(.seconds(5)) == "00:00:05")
        #expect(hours.format(.zero) == "00:00:00")
        #expect(TimerClockFormatStyle().format(.seconds(30)) == "00:30")
        #expect(TimerClockFormatStyle().format(.zero) == "00:00")
    }

    @Test("초 미만을 생략하고 유효 범위 검증을 표시 형식과 분리한다")
    func presentsWholeSeconds() {
        let duration = TimerDurationFormatStyle()
        #expect(duration.format(.seconds(5.9)) == "5초")
        #expect(duration.format(.seconds(-5)) == "-5초")
        #expect(duration.format(.seconds(-8_160)) == "-2시간 16분")
        #expect(duration.format(.seconds(86_400)) == "24시간")
        #expect(TimerClockFormatStyle().format(.seconds(59.9)) == "00:59")
    }
}
