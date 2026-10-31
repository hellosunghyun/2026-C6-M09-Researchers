import SwiftUI
import Testing

@testable import LabcordDesignSystem

@Suite("원본 디자인 토큰")
struct ThemeTests {
    @Test("최종 Foundation과 별도 컴포넌트 역할의 두 모드 RGBA가 일치한다")
    func matchesSourceColors() throws {
        let archive = try sourceArchive()
        let environment = EnvironmentValues()

        for context in ThemeContext.allCases {
            let theme = LabcordTheme(context: context)
            let mode = context == .general ? "General" : "Experiment"

            for token in ColorToken.allCases {
                let rgba = try archive.color(for: token.rawValue, mode: mode)
                let expected = Color(
                    red: rgba.red,
                    green: rgba.green,
                    blue: rgba.blue,
                    opacity: rgba.opacity
                ).resolve(in: environment)
                let actual = theme.color(token).resolve(in: environment)
                #expect(abs(actual.red - expected.red) < 0.00001)
                #expect(abs(actual.green - expected.green) < 0.00001)
                #expect(abs(actual.blue - expected.blue) < 0.00001)
                #expect(abs(actual.opacity - expected.opacity) < 0.00001)
            }
        }

        let background = try archive.color(for: "Background/Primary", mode: "Experiment")
        #expect(abs(background.red - (17.0 / 255.0)) < 0.00001)
        #expect(abs(background.green - (19.0 / 255.0)) < 0.00001)
        #expect(abs(background.blue - (19.0 / 255.0)) < 0.00001)

        let secondaryLabel = try archive.color(for: "Label/Secondary", mode: "Experiment")
        #expect(abs(secondaryLabel.opacity - 0.7200000286) < 0.00001)

        for mode in ["General", "Experiment"] {
            let primaryAction = try archive.color(for: "Action/Primary/Background", mode: mode)
            #expect(abs(primaryAction.red - (32.0 / 255.0)) < 0.00001)
            #expect(abs(primaryAction.green - (188.0 / 255.0)) < 0.00001)
            #expect(abs(primaryAction.blue - (137.0 / 255.0)) < 0.00001)
        }

        let timerIdentity = try #require(
            archive.actualComponentBindings.rows.first { $0.name == "Timer/Identity/01" }
        )
        #expect(timerIdentity.code["iOS"] == "recordTimerIdentity01")
    }

    @Test("타임라인 메모 배경은 원격 Colors 변수의 모드와 consumer를 보존한다")
    func matchesTimelineMemoBackgroundSource() throws {
        let archive = try sourceArchive()
        let memoBackground = try #require(
            archive.actualComponentBindings.componentSpecificBindings.first {
                $0.role == ColorToken.timelineMemoBackground.rawValue
            }
        )
        #expect(
            memoBackground.source.variableId
                == "VariableID:5a7b03b0f3ad38574fceb8e18b544f77065d1c5b/5720:190"
        )
        #expect(
            memoBackground.source.collectionId
                == "VariableCollectionId:0c5d0248cef768d2e14620cb1e70d045b5ccc258/5720:155"
        )
        #expect(memoBackground.themeModeMap["General"] == "Light")
        #expect(memoBackground.themeModeMap["Experiment"] == "Dark")
        #expect(Set(memoBackground.consumerIds) == Set(["936:20618", "936:20622"]))

        let light = try #require(
            memoBackground.entries.first { $0.modeName == "Light" }?.resolved.color
        )
        #expect(abs(light.red - 0.45490196347236633) < 0.00001)
        #expect(abs(light.green - 0.45490196347236633) < 0.00001)
        #expect(abs(light.blue - 0.501960813999176) < 0.00001)
        #expect(abs(light.opacity - 0.07999999821186066) < 0.00001)

        let dark = try #require(
            memoBackground.entries.first { $0.modeName == "Dark" }?.resolved.color
        )
        #expect(abs(dark.red - 0.4627451002597809) < 0.00001)
        #expect(abs(dark.green - 0.4627451002597809) < 0.00001)
        #expect(abs(dark.blue - 0.501960813999176) < 0.00001)
        #expect(abs(dark.opacity - 0.18000000715255737) < 0.00001)

        try assertTimerSheetGrabberSource(archive)
    }

    private func assertTimerSheetGrabberSource(_ archive: TokenArchive) throws {
        let grabber = try #require(
            archive.actualComponentBindings.componentSpecificBindings.first {
                $0.role == ColorToken.timerSheetGrabber.rawValue
            }
        )
        #expect(
            grabber.source.variableId
                == "VariableID:6ea4c4662c5ffb219f85c031a9719fe3dfb260d5/5720:221"
        )
        #expect(
            grabber.source.collectionId
                == "VariableCollectionId:0c5d0248cef768d2e14620cb1e70d045b5ccc258/5720:155"
        )
        #expect(grabber.themeModeMap["General"] == "Light")
        #expect(grabber.themeModeMap["Experiment"] == "Dark")
        #expect(grabber.consumerIds == ["1208:11461"])

        let light = try #require(grabber.entries.first { $0.modeName == "Light" }?.resolved.color)
        #expect(abs(light.red - 0.800000011920929) < 0.00001)
        #expect(abs(light.green - 0.800000011920929) < 0.00001)
        #expect(abs(light.blue - 0.800000011920929) < 0.00001)
        #expect(abs(light.opacity - 1) < 0.00001)

        let dark = try #require(grabber.entries.first { $0.modeName == "Dark" }?.resolved.color)
        #expect(abs(dark.red - 0.20000000298023224) < 0.00001)
        #expect(abs(dark.green - 0.20000000298023224) < 0.00001)
        #expect(abs(dark.blue - 0.20000000298023224) < 0.00001)
        #expect(abs(dark.opacity - 1) < 0.00001)
    }

    @Test("현재 맥락은 기기 밝기와 독립적이고 system만 밝기를 따른다")
    func resolvesAppearanceAtUseSite() {
        let tokens: [ColorToken] = [
            .backgroundPrimary, .effectShadowSoftColor,
            .effectShadowMediumColor, .effectShadowStrongColor
        ]
        for context in ThemeContext.allCases {
            for colorScheme in [ColorScheme.light, .dark] {
                let systemContext: ThemeContext = colorScheme == .dark ? .experiment : .general
                for appearance in [ThemeAppearance.current, .system] {
                    let theme = LabcordTheme(context: context, appearance: appearance)
                    var environment = EnvironmentValues()
                    environment.colorScheme = colorScheme
                    environment.labcordTheme = theme
                    let expectedContext = appearance == .system ? systemContext : context
                    for token in tokens {
                        let actual = LabcordColor(token).resolve(in: environment)
                        #expect(actual == LabcordTheme(context: expectedContext).color(token))
                        #expect(theme.color(token, colorScheme: colorScheme) == actual)
                    }
                }
            }

            let light = LabcordTheme(context: context, appearance: .light)
            let dark = LabcordTheme(context: context, appearance: .dark)
            #expect(light.color(.backgroundPrimary) == LabcordTheme().color(.backgroundPrimary))
            #expect(
                dark.color(.backgroundPrimary)
                == LabcordTheme(context: .experiment).color(.backgroundPrimary)
            )
        }
    }

    @Test("간격·모서리·효과 수치는 원본 변수와 일치한다")
    func matchesSourceMetrics() throws {
        let archive = try sourceArchive()

        for token in LayoutToken.allCases {
            let variable = try #require(archive.variables.first { $0.name == token.rawValue })
            let expected = try #require(variable.entries.first?.resolved.value)
            #expect(abs(Double(LayoutTokens()[token]) - expected) < 0.00001)
        }

        for context in ThemeContext.allCases {
            let mode = context == .general ? "General" : "Experiment"
            for token in EffectToken.allCases {
                let expected = try archive.value(for: token.rawValue, mode: mode)
                #expect(abs(Double(EffectTokens(context: context)[token]) - expected) < 0.00001)
            }
        }
    }

    private func sourceArchive() throws -> TokenArchive {
        let source = Bundle.module.url(forResource: "DesignTokens", withExtension: "json")
        let url = try #require(source)
        return try JSONDecoder().decode(TokenArchive.self, from: Data(contentsOf: url))
    }
}

private struct TokenArchive: Decodable {
    let source: ArchiveSource?
    let variables: [Variable]
    let actualComponentBindings: ActualComponentBindings

    func color(for name: String, mode: String) throws -> TokenRGBA {
        if let componentBinding = actualComponentBindings.componentSpecificBindings.first(
            where: { $0.role == name }
        ) {
            let sourceMode = try #require(componentBinding.themeModeMap[mode])
            let entry = try #require(
                componentBinding.entries.first { $0.modeName == sourceMode }
            )
            return entry.resolved.color
        }

        if source?.currentFoundation == nil,
           let selectedID = actualComponentBindings.roleVariableIDs[name] {
            let row = try #require(actualComponentBindings.rows.first { $0.id == selectedID })
            #expect(row.name == name)
            #expect(row.collection == actualComponentBindings.source.collectionID)
            let resolved = try #require(row.resolved.first { $0.mode == mode })
            guard case let .color(value) = resolved.value else {
                throw SourceArchiveError.invalidColorValue(name)
            }
            return value
        }

        let variable = try #require(variables.first { $0.name == name })
        let entry = try #require(variable.entries.first { $0.modeName == mode })
        return try #require(entry.resolved.color)
    }

    func value(for name: String, mode: String) throws -> Double {
        if source?.currentFoundation == nil,
           let selectedID = actualComponentBindings.roleVariableIDs[name] {
            let row = try #require(actualComponentBindings.rows.first { $0.id == selectedID })
            #expect(row.name == name)
            #expect(row.collection == actualComponentBindings.source.collectionID)
            let resolved = try #require(row.resolved.first { $0.mode == mode })
            guard case let .number(value) = resolved.value else {
                throw SourceArchiveError.invalidNumericValue(name)
            }
            return value
        }

        let variable = try #require(variables.first { $0.name == name })
        let entry = try #require(variable.entries.first { $0.modeName == mode })
        return try #require(entry.resolved.value)
    }

    struct Variable: Decodable {
        let name: String
        let entries: [Entry]
    }

    struct ArchiveSource: Decodable {
        let currentFoundation: CurrentFoundation?
    }

    struct CurrentFoundation: Decodable {
        let fileKey: String
    }

    struct Entry: Decodable {
        let modeName: String
        let resolved: Resolved
    }

    struct Resolved: Decodable {
        let value: Double?
        let color: TokenRGBA?
    }

    struct ActualComponentBindings: Decodable {
        let source: ActualSource
        let rows: [ActualRow]
        let roleVariableIDs: [String: String]
        let componentSpecificBindings: [ComponentSpecificBinding]
    }

    struct ComponentSpecificBinding: Decodable {
        let role: String
        let source: ComponentSource
        let themeModeMap: [String: String]
        let entries: [ComponentEntry]
        let consumerIds: [String]
    }

    struct ComponentSource: Decodable {
        let variableId: String
        let collectionId: String
    }

    struct ComponentEntry: Decodable {
        let modeName: String
        let resolved: ComponentResolved
    }

    struct ComponentResolved: Decodable {
        let color: TokenRGBA
    }
}

private struct ActualSource: Decodable {
    let collectionID: String

    enum CodingKeys: String, CodingKey {
        case collectionID = "collectionId"
    }
}

private struct ActualRow: Decodable {
    let id: String
    let name: String
    let collection: String
    let code: [String: String]
    let resolved: [ActualResolved]
}

private struct ActualResolved: Decodable {
    let mode: String
    let value: SourceValue
}

private enum SourceValue: Decodable {
    case color(TokenRGBA)
    case number(Double)

    init(from decoder: Decoder) throws {
        if let color = try? TokenRGBA(from: decoder) {
            self = .color(color)
        } else {
            self = .number(try decoder.singleValueContainer().decode(Double.self))
        }
    }
}

private enum SourceArchiveError: Error {
    case invalidColorValue(String)
    case invalidNumericValue(String)
}

private struct TokenRGBA: Decodable {
    let red: Double
    let green: Double
    let blue: Double
    let opacity: Double

    enum CodingKeys: String, CodingKey {
        case red = "r"
        case green = "g"
        case blue = "b"
        case opacity = "a"
    }
}
