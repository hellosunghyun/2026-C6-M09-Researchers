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

    func testStandaloneMRequiresAnExplicitLengthContext() {
        let physical = [
            "길이 10m", "높이는 5 m", "깊이: 3m", "너비 1~5m", "length of 2m",
            "depth = 4 m", "5m long", "5m in height", "5m 깊이", "높이(m)", "단위 [m]"
        ]
        for source in physical {
            XCTAssertEqual(ProtocolDocumentUnitExtractor.extract(from: source), ["m"], source)
        }
        let durations = [
            "Incubate for 5 m", "Wait 5m", "5m 동안 배양", "5m", "5m30s", "5m for incubation"
        ]
        for source in durations {
            XCTAssertEqual(ProtocolDocumentUnitExtractor.extract(from: source), [], source)
        }
    }

    func testLengthContextDoesNotLeakAcrossAnotherDurationOrClause() {
        XCTAssertEqual(ProtocolDocumentUnitExtractor.extract(from: "길이 10cm, incubate for 5m"),
                       ["cm"])
        XCTAssertEqual(ProtocolDocumentUnitExtractor.extract(from: "길이 10m, incubate for 5m"),
                       ["m"])
        XCTAssertEqual(ProtocolDocumentUnitExtractor.extract(from: "배양 후 길이 10m를 측정"),
                       ["m"])
    }

    func testBufferEquationSymbolsDoNotBecomeMeasurements() {
        // 실제 완충용액 PDF의 OCR 수식·농도 변수·읽기자료 발췌.
        let source = """
            (CH3)3NH+/(CH3)3N
            (CH3)зNH+/(CH3)зN
            DH~ Dk.- l08 TA]0
            pH = pK. - 108 TA-lo
            두 값은 [HA]와 [A] o에 비하여 작다.
            높이가 3km 정도 되는 산을 이틀 만에 올라간다.
            0.1M 아세트산 수용액 50mL를 비커에 넣는다.
            순수한 물 1L의 pH를 측정한다.
            """
        XCTAssertEqual(ProtocolDocumentUnitExtractor.extract(from: source),
                       ["pH", "km", "M", "mL", "L"])
    }

    func testConductanceMethodIdentifiersAndVariablesAreNotUnitHeaders() {
        // 실제 METHOD 9050A PDF의 문서 번호·계산 변수·표준 용액 발췌.
        let source = """
            METHOD 9050A
            CD-ROM 9050A - 1 Revision 1
            K = conductivity
            (K )(1,000,000)(C)
            of 0.01 N KCl solution.
            """
        XCTAssertEqual(ProtocolDocumentUnitExtractor.extract(from: source), ["N"])
        XCTAssertEqual(ProtocolDocumentUnitExtractor.extract(from: "(A) [N] (K)"), [])
    }

    func testElectricalUnitsKeepSiemensAndActualMhoNotations() {
        // 같은 전도도 PDF가 단위 설명과 표 머리글에서 수치 없이 사용하는 표기입니다.
        let source = """
            where: Km = measured conductivity, uS at t°C
            When sample conductivity is measured, conductivity at 25°C is:
            conductivity is reported as millisiemens per meter (mS/m);
            mS/m = 10 umhos/cm and 1 uS/cm = 1 umho/cm.
            mS/m = 10 µmhos/cm and 1 µS/cm = 1 µmho/cm.
            siemens (S)
            uS/cm Results % %
            """
        XCTAssertEqual(ProtocolDocumentUnitExtractor.extract(from: source), [
            "uS", "°C", "mS/m", "umhos/cm", "uS/cm", "umho/cm", "S", "%"
        ])
    }

    func testRealHeadersKeepCommonUnitsWithoutTreatingChemicalBracketsAsHeaders() {
        let source = """
            concentration (mM)
            volume [mL]
            mg
            current (A)
            normality (N)
            temperature (K)
            """
        XCTAssertEqual(ProtocolDocumentUnitExtractor.extract(from: source),
                       ["mM", "mL", "mg", "A", "N", "K"])
        XCTAssertEqual(ProtocolDocumentUnitExtractor.extract(from: "3A; 1e3 A; 0.01 N"),
                       ["A", "N"])
    }

    func testComparisonKeysPreserveScaleAndPhysicalUnitCase() {
        XCTAssertEqual(Set(["mM", "mm", "M", "m"].map(ProtocolTermNormalizer.key)).count, 4)
        XCTAssertNotEqual(ProtocolTermNormalizer.key("mPa"), ProtocolTermNormalizer.key("MPa"))
        XCTAssertNotEqual(ProtocolTermNormalizer.key("mA"), ProtocolTermNormalizer.key("MA"))
        XCTAssertNotEqual(ProtocolTermNormalizer.key("mL"), ProtocolTermNormalizer.key("ML"))
        XCTAssertEqual(ProtocolTermNormalizer.key(" ＡＳＰＩＲＩＮ "),
                       ProtocolTermNormalizer.key("aspirin"))
        XCTAssertEqual(ProtocolTermNormalizer.key("아스피린(Aspirin)"),
                       ProtocolTermNormalizer.key("아스피린(ASPIRIN)"))
    }

    func testComparisonKeysNormalizeMicroAndLitreOnlyAtUnitBoundaries() {
        for variant in ["uS/cm", "µS/cm", "μS / cm"] {
            XCTAssertEqual(ProtocolTermNormalizer.key(variant), "μS/cm", variant)
        }
        for variant in ["ul", "uL", "µl", "μL", "㎕"] {
            XCTAssertEqual(ProtocolTermNormalizer.key(variant), "μL", variant)
        }
        for variant in ["ml", "mL", "ｍＬ", "㎖"] {
            XCTAssertEqual(ProtocolTermNormalizer.key(variant), "mL", variant)
        }
        XCTAssertEqual(ProtocolTermNormalizer.key("ug/ml"), "μg/mL")
        XCTAssertEqual(ProtocolTermNormalizer.key("mg/ul"), "mg/μL")
        XCTAssertEqual(ProtocolTermNormalizer.key("umol/ml"), "μmol/mL")
        XCTAssertEqual(ProtocolTermNormalizer.key("nmol/L"), "nmol/L")
        XCTAssertEqual(ProtocolTermNormalizer.key("mol"), "mol")
        XCTAssertEqual(ProtocolTermNormalizer.key("W/m²"), ProtocolTermNormalizer.key("W/m2"))
    }

    func testUnitAliasesDeduplicateWhileKeepingFirstSourceSpellingAndDifferentScales() {
        let source = "1 uS/cm; 2 µS/cm; 3 ml; 4 mL; 5 ul; 6 µL; 7 mM; 8 mm; 9 M"
        XCTAssertEqual(ProtocolDocumentUnitExtractor.extract(from: source),
                       ["uS/cm", "ml", "ul", "mM", "mm", "M"])
        let terms = ProtocolExtractedTerms(units: ["µS/cm", "mL", "μL"])
        let result = ProtocolDocumentUnitExtractor.supplement(terms, from: source)
        XCTAssertEqual(result.units, ["µS/cm", "mL", "μL", "mM", "mm", "M"])
    }
}
