//
//  Theme.swift
//  labcord-package-swift
//
//  화면 맥락과 appearance를 분리한 테마 환경
//

import SwiftUI

/// 화면이 사용하는 제품 맥락입니다.
public enum ThemeContext: String, CaseIterable, Sendable {
    case general
    case experiment
}

/// 현재 화면 표현과 향후 밝기 전환을 구분하는 선택 정책입니다.
public enum ThemeAppearance: String, CaseIterable, Sendable {
    case current
    case light
    case dark
    case system
}

/// Labcord 디자인 토큰을 해석하는 불변 테마 설정입니다.
///
/// `context`는 현재 표현의 제품 맥락이고, `appearance`는 밝기 선택 정책입니다.
/// 두 값을 분리해 두어 기존 화면 표현을 유지하면서 system appearance를 도입할 수 있습니다.
public struct LabcordTheme: Sendable {
    public let context: ThemeContext
    public let appearance: ThemeAppearance

    public init(
        context: ThemeContext = .general,
        appearance: ThemeAppearance = .current
    ) {
        self.context = context
        self.appearance = appearance
    }

    /// Foundation 컬렉션에서 확인된 spacing과 radius 토큰입니다.
    public var layout: LayoutTokens {
        LayoutTokens()
    }

    /// 현재 테마 appearance에 대응하는 effect 수치 토큰입니다.
    /// `.system`을 View 밖에서 읽는 경우 context를 fallback으로 사용합니다.
    public var effects: EffectTokens {
        EffectTokens(context: resolvedContext(for: nil))
    }

    /// Environment의 colorScheme을 적용해 effect 수치 토큰을 해석합니다.
    public func effects(for colorScheme: ColorScheme) -> EffectTokens {
        EffectTokens(context: resolvedContext(for: colorScheme))
    }

    internal func resolvedContext(for colorScheme: ColorScheme?) -> ThemeContext {
        switch appearance {
        case .current:
            return context
        case .light:
            return .general
        case .dark:
            return .experiment
        case .system:
            guard let colorScheme else { return context }
            return colorScheme == .dark ? .experiment : .general
        }
    }
}

private struct LabcordThemeKey: EnvironmentKey {
    static let defaultValue = LabcordTheme()
}

public extension EnvironmentValues {
    var labcordTheme: LabcordTheme {
        get { self[LabcordThemeKey.self] }
        set { self[LabcordThemeKey.self] = newValue }
    }
}

public extension View {
    /// 하위 View 계층에 LabcordTheme을 주입합니다.
    func labcordTheme(_ theme: LabcordTheme) -> some View {
        environment(\.labcordTheme, theme)
    }
}
