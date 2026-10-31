import CoreText
import SwiftUI
import Testing

@testable import LabcordDesignSystem

@Suite("Typography")
@MainActor
struct TypographyTests {
    @Test("Pretendard 등록은 반복 호출해도 성공하고 실제 글꼴을 사용한다")
    func registersPackagedFont() {
        #expect(FontRegistration.register())
        #expect(FontRegistration.register())

        #if os(iOS)
        let font = CTFontCreateWithName("PretendardVariable-Regular" as CFString, 17, nil)
        #expect(CTFontCopyPostScriptName(font) as String == "PretendardVariable-Regular")
        #endif
    }

    #if os(iOS)
    @Test("접근성 글자 크기에서도 두 줄이 한 줄 높이를 침범하지 않는다")
    func accessibilityLineHeight() throws {
        #expect(FontRegistration.register())
        let single = try renderedSize("실험 기록", size: .accessibility3)
        let multiple = try renderedSize("실험 기록\n실험 기록", size: .accessibility3)
        #expect(multiple.height >= single.height * 1.8)
    }

    @Test("Dynamic Type을 확대하면 실제 표시 크기가 커진다")
    func scalesWithDynamicType() throws {
        #expect(FontRegistration.register())
        let normal = try renderedSize("실험 기록", size: .large)
        let enlarged = try renderedSize("실험 기록", size: .accessibility3)
        #expect(enlarged.width > normal.width)
        #expect(enlarged.height > normal.height)
    }

    private func renderedSize(_ text: String, size: DynamicTypeSize) throws -> CGSize {
        let content = Text(text)
            .typography(Typography.body)
            .environment(\.dynamicTypeSize, size)
            .fixedSize()
        let renderer = ImageRenderer(content: content)
        return try #require(renderer.uiImage).size
    }
    #endif
}
