import ComposableArchitecture
import LabcordDesignSystem
import SwiftUI

struct ProtocolRegistrationView: View {
    @Bindable var store: StoreOf<ProtocolRegistrationFeature>

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 8) {
                    ProtocolUploadButton("사진", description: "PNG, JPG", state: .default) {
                        store.send(.sourceTapped(.photos))
                    }
                    .accessibilityIdentifier("entry-source-photos")

                    ProtocolUploadButton("파일", description: "PDF, XLSX, DOCX", state: .default) {
                        store.send(.sourceTapped(.file))
                    }
                    .accessibilityIdentifier("entry-source-file")

                    ProtocolUploadButton(
                        "최근 사용한 프로토콜", description: "", state: .default,
                        showDescription: false
                    ) {
                        store.send(.sourceTapped(.recent))
                    }
                    .accessibilityIdentifier("entry-source-recent")
                }
                .disabled(store.isSaving)
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }

            VStack(spacing: 8) {
                Button {
                    store.send(.skipTapped)
                } label: {
                    HStack(spacing: 6) {
                        if store.isSaving {
                            EntryLoadingIndicator()
                        }
                        Text(store.isSaving ? "실험을 저장하고 있어요" : "프로토콜 없이 진행")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.labcord(.accent, size: .medium))
                .disabled(store.isSaving)
                .accessibilityIdentifier("entry-skip")

                EntryNextButton()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        }
        .alert("실험을 저장하지 못했어요", isPresented: Binding(
            get: { store.hasFailed },
            set: { if !$0 { store.send(.dismissFailure) } }
        )) {
            Button("재시도") { store.send(.retryTapped) }
            Button("취소", role: .cancel) { store.send(.dismissFailure) }
        } message: {
            Text("실험은 등록되지 않았어요. 다시 시도해 주세요.")
        }
        .navigationTitle("실험 등록")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("뒤로 가기", systemImage: "chevron.backward") {
                    store.send(.backTapped)
                }
                .disabled(store.isSaving)
                .accessibilityIdentifier("entry-back")
            }
        }
    }
}

private struct EntryLoadingIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                ProgressView()
            } else {
                ProgressView()
                    .phaseAnimator([CGFloat(0.8), 1.15]) { content, scale in
                        content.scaleEffect(scale)
                    } animation: { _ in
                        .easeInOut(duration: 0.8)
                    }
            }
        }
        .controlSize(.mini)
        .frame(width: 18, height: 18)
        .accessibilityLabel("실험 저장 중")
    }
}

private struct EntryNextButton: View {
    var body: some View {
        Button {} label: {
            Text("다음")
                .font(.body)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.labcord(.primary, size: .large))
        .disabled(true)
        .accessibilityIdentifier("entry-next")
    }
}
