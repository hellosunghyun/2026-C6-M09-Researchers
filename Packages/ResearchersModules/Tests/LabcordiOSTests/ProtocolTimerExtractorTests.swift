import Foundation
@testable import LabcordiOS
import XCTest

final class ProtocolTimerExtractorTests: XCTestCase {
    func testWindSpeedDoesNotProduceScreenshotTimers() {
        let text = """
            1.0 m/s, 5 m/s, 1.0 m/s, 1.0 m/s,
            70 m/s, 70 m/s, 1.0 m/s, 70 m/s
            """
        XCTAssertEqual(ProtocolTimerExtractor.extract(from: text), [])
    }

    func testCompoundPhysicalUnitsAreNotDurations() {
        let values = [
            "1 m/h", "2 mm/h", "3 ㎜/h", "4 m²", "5 m^2", "6 m·s^-1",
            "7 s^-1", "8 s⁻¹", "9 s/min", "10 m / s", "11 mm²", "12 m2", "13 m s⁻¹"
        ]
        for value in values {
            XCTAssertEqual(ProtocolTimerExtractor.extract(from: value), [], value)
        }
    }

    func testKoreanAndEnglishCompactDurations() {
        let values: [(String, [Int])] = [
            ("1시간10분", [4_200]), ("1분30초", [90]),
            ("1h30m", [5_400]), ("5m30s", [330]),
            ("30초간 가열", [30]), ("1.5분 냉각", [90]),
            ("5 min", [300]), ("30 sec", [30])
        ]
        for (text, expected) in values {
            XCTAssertEqual(ProtocolTimerExtractor.extract(from: text), expected, text)
        }
    }

    func testCompoundDurationsDoNotJoinAcrossLinesOrRestartedUnits() {
        XCTAssertEqual(ProtocolTimerExtractor.extract(from: "1분 30초\n2분 10초"), [90, 130])
        XCTAssertEqual(ProtocolTimerExtractor.extract(from: "1분 30초 2분 10초"), [90, 130])
        XCTAssertEqual(ProtocolTimerExtractor.extract(from: "1시간\n10분"), [3_600, 600])
    }

    func testEquivalentDurationsKeepFirstOccurrenceOrder() {
        let text = "30초; 1시간10분; 70분; 1분; 60초; 1시간 10분; 30 sec"
        XCTAssertEqual(ProtocolTimerExtractor.extract(from: text), [30, 4_200, 60])
    }

    func testKoreanWordBoundariesAndRatesAreNotDurations() {
        let values = [
            "1분석 시료", "1분당 60회", "1시간당 3회", "60분/시간당",
            "10m 길이", "1분의 오차", "A10s", "70S protein", "5ml 3ms"
        ]
        for value in values {
            XCTAssertEqual(ProtocolTimerExtractor.extract(from: value), [], value)
        }
    }

    func testRangesAreNotConvertedToFixedTimers() {
        let values = [
            "10~20분", "10분~20분", "10 to 20 min", "0.5min-1min",
            "1시간10분~2시간20분", "10분에서20분", "10분부터20분까지"
        ]
        for value in values {
            XCTAssertEqual(ProtocolTimerExtractor.extract(from: value), [], value)
        }
        XCTAssertEqual(ProtocolTimerExtractor.extract(from: "10~20분 후 30초 가열"), [30])
    }

    func testClockTimesAndOriginalVolumeGuardsRemainExcluded() {
        XCTAssertEqual(ProtocolTimerExtractor.extract(from: "01:02:03 유지"), [3_723])
        XCTAssertEqual(ProtocolTimerExtractor.extract(from: "오전 01:02:03 기록"), [])
        XCTAssertEqual(ProtocolTimerExtractor.extract(from: "-5분; 10mL; 3ms"), [])
    }
}
