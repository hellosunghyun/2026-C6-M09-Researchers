import LabcordDesignSystem
import SwiftUI

struct ProtocolAnalysisProgressView: View {
    let phase: ProtocolAnalysisPhase
    let isCancelling: Bool
    let onCancel: () -> Void

    private var statusText: String {
        if isCancelling { return "분석 취소 중..." }
        switch phase {
        case .reading: return "프로토콜을 읽고 있어요"
        case .extractingTerms: return "타이머와 용어를 찾고 있어요"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    ProgressView()
                        .progressViewStyle(.labcord(
                            size: .large,
                            foreground: Color(
                                "General/Label/Brand", bundle: LabcordDesignSystemResources.bundle
                            )
                        ))
                        .scaleEffect(2)
                        .frame(width: 160, height: 160)
                        .accessibilityLabel("프로토콜 분석 중")

                    VStack(spacing: 8) {
                        Text(isCancelling ? "분석을 취소하고 있어요" : "프로토콜 분석 중...")
                            .typography(Typography.title3SemiBold)
                        Text("프로토콜 기반으로 실험 준비 중이에요.")
                            .typography(Typography.subheadline)
                            .foregroundStyle(Color(
                                "General/Label/Secondary",
                                bundle: LabcordDesignSystemResources.bundle
                            ))
                    }
                    .multilineTextAlignment(.center)
                    .padding(.top, 32)

                    Text(statusText)
                        .typography(Typography.calloutSemiBold)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color(
                            "General/Fill/Primary", bundle: LabcordDesignSystemResources.bundle
                        ), in: Capsule())
                        .padding(.top, 48)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.top, 32)
            }

            VStack(spacing: 12) {
                Text("분석을 건너뛰고, 실험을 시작할 수 있어요.")
                    .typography(Typography.subheadline)
                    .foregroundStyle(Color(
                        "General/Label/Secondary", bundle: LabcordDesignSystemResources.bundle
                    ))
                    .multilineTextAlignment(.center)
                Button(action: onCancel) {
                    Text(isCancelling ? "취소 중..." : "분석 건너뛰기")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.labcord(.secondary, size: .large))
                .disabled(isCancelling)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .accessibilityIdentifier("protocol-analysis-progress")
    }
}
