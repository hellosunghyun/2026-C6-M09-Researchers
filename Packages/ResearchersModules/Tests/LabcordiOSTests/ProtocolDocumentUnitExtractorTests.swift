import Foundation
@testable import LabcordiOS
import XCTest

final class ProtocolDocumentUnitExtractorTests: XCTestCase {
    func testAspirinMeasurementsAreRecoveredWithoutSelectingTheirNumbers() {
        let source = """
            바이엘 아스피린, 500mg
            F.W: 102.9g/mol
            d: 1.082g/mL
            살리실산 1.0g을 삼각플라스크에 넣고 아세트산 무수물 3mL를 넣는다.
            85% 인산 3~4 방울을 넣고 70~85°C로 유지하여 10분간 가열한다.
            수득률(%) = 얻은 질량 / 이론적인 질량
            """
        XCTAssertEqual(ProtocolDocumentUnitExtractor.extract(from: source),
                       ["mg", "g/mol", "g/mL", "g", "mL", "%", "°C"])
    }

    func testWeatherCompoundsAndHumidityKeepTheirActualNotation() {
        let source = """
            마지막 자리는 0.1
            W/m2로 한다. 검정점은 60 ℃이며 중간점(°C)을 검정한다.
            습도계는 30, 60, 90 %R.H.이며 풍속 1.0 m/s로 한다.
            검정점의 R.H.를 기록하고 풍향은 360°를 16방위로 검정한다.
            """
        XCTAssertEqual(ProtocolDocumentUnitExtractor.extract(from: source),
                       ["W/m2", "℃", "%R.H.", "m/s", "R.H.", "°"])
    }

    func testSICompoundFormsMicroAndWidthVariants() {
        let source = "2 W/m²; 3 W/m2; 4 μL; 5 µL; 6 m·s⁻¹; 7 m s^-1; 8 kg/m³; 9 ㎖"
        XCTAssertEqual(ProtocolDocumentUnitExtractor.extract(from: source),
                       ["W/m²", "μL", "m·s⁻¹", "m s^-1", "kg/m³", "㎖"])
    }

    func testUnitCaseIsNotFoldedBetweenLengthAndConcentration() {
        let source = "2 mm; 3 mM; 4 M; 5 mol/L; pH 7.4; OD600 0.5"
        XCTAssertEqual(ProtocolDocumentUnitExtractor.extract(from: source),
                       ["mm", "mM", "M", "mol/L", "pH", "OD600"])
    }

    func testPercentNotationsAndConcentrationNamesAreSeparate() {
        let source = "70%에탄올, 100%ethanol, 10%(v/v) DMSO, 20% (w/v)"
        let terms = ProtocolExtractedTerms(materials: ["70%에탄올", "DMSO"],
                                          glossaryTerms: ["에탄올"])
        let result = ProtocolDocumentUnitExtractor.supplement(terms, from: source)
        XCTAssertEqual(result.materials, ["70%에탄올", "DMSO"])
        XCTAssertEqual(result.glossaryTerms, ["에탄올"])
        XCTAssertEqual(result.units, ["%", "%(v/v)", "% (w/v)"])
    }

    func testDurationsNamesAndBrokenOCRAreNotInventedAsUnits() {
        let source = """
            Add DMSO and NaCl for 10 min, 30 s, and 1 h.
            COOH + H2O → CH3COOH. R. Wm? 70S protein 3ms
            살리실산(salicylic acid), 자동적설계, 검정
            """
        XCTAssertEqual(ProtocolDocumentUnitExtractor.extract(from: source), [])
    }

    func testSupplementMovesOnlyExactUnitTermsAndPreservesFallbackAndOrder() {
        let terms = ProtocolExtractedTerms(
            materials: ["살리실산", "mL"], samples: ["시료"],
            glossaryTerms: ["W/m²", "교반"], units: ["°C", "μL"], usedFallback: true
        )
        let result = ProtocolDocumentUnitExtractor.supplement(
            terms, from: "2 mL의 시료, 70 ℃, 1 µL, 일사 0.1 W/m2"
        )
        XCTAssertEqual(result.materials, ["살리실산"])
        XCTAssertEqual(result.samples, ["시료"])
        XCTAssertEqual(result.glossaryTerms, ["교반"])
        XCTAssertEqual(result.units, ["°C", "μL", "mL", "W/m2"])
        XCTAssertTrue(result.usedFallback)
    }

    func testCompoundUnitsAreClassifiedAsUnitsWithoutChangingChemicalCase() {
        for unit in ["m/s", "W/m²", "%R.H.", "R.H.", "kg/m³", "µL", "°C", "rpm"] {
            XCTAssertTrue(ProtocolTermNormalizer.isUnit(unit), unit)
        }
        for term in ["Wm?", "R.", "NaCl", "COOH", "살리실산", "기압계"] {
            XCTAssertFalse(ProtocolTermNormalizer.isUnit(term), term)
        }
    }

    func testCompletedClassificationSupplementsUnitsWithoutRepeatingCheckpoint() async throws {
        let seed = ProtocolExtractedTerms(materials: ["아스피린"])
        let result = try await ProtocolTermClassifier.classifyDocument(
            ["아스피린"], context: "아스피린을 3mL에 넣고 10분간 가열한다.", seed: seed
        ) { _ in XCTFail("A completed prefix must not be classified again") }
        XCTAssertEqual(result.materials, ["아스피린"])
        XCTAssertEqual(result.units, ["mL"])
        XCTAssertFalse(result.usedFallback)
    }
}
