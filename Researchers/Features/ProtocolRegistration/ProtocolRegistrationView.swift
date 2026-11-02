import ComposableArchitecture
import LabcordDesignSystem
import LabcordiOS
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ProtocolRegistrationView: View {
    @Bindable var store: StoreOf<ProtocolRegistrationFeature>
    @State private var photoPickerPresented = false
    @State private var filePickerPresented = false
    @State private var photoSelection: [PhotosPickerItem] = []
    @State private var importFailed = false
    @State private var analysisTask: Task<Void, Never>?
    @State private var showReviewConfirmation = false
    @State private var showSkipConfirmation = false
    @State private var showExitConfirmation = false
    @State private var skipAfterCancellation = false
    @Dependency(\.protocolAnalysisClient) private var analysisClient

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 8) {
                    ProtocolUploadButton(
                        "사진", description: "PNG, JPG",
                        state: store.importedPhotos.isEmpty ? .default : .selected
                    ) {
                        photoPickerPresented = true
                    }
                    .accessibilityIdentifier("entry-source-photos")

                    ProtocolUploadButton(
                        "파일", description: "PDF, XLSX, DOCX",
                        state: store.importedFile == nil ? .default : .selected
                    ) {
                        filePickerPresented = true
                    }
                    .accessibilityIdentifier("entry-source-file")

                    if let importedFile = store.importedFile {
                        HStack {
                            Text(importedFile.name).lineLimit(1)
                            Spacer()
                            Button("삭제", systemImage: "xmark") { store.send(.removeFile) }
                                .labelStyle(.iconOnly)
                        }
                        .padding(.horizontal, 16)
                    }

                    if store.importing {
                        ProgressView("파일을 가져오고 있어요")
                    }

                    ProtocolUploadButton(
                        "최근 사용한 프로토콜", description: "", state: .default,
                        showDescription: false
                    ) {
                        store.send(.sourceTapped(.recent))
                    }
                    .accessibilityIdentifier("entry-source-recent")
                }
                .disabled(store.isSaving || store.importing || store.analysisID != nil)
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }

            VStack(spacing: 8) {
                if !store.importedPhotos.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(store.importedPhotos) { photo in
                                ProtocolPhotoItem {
                                    store.send(.removePhoto(photo.id))
                                } content: {
                                    ProtocolPhotoThumbnail(url: photo.url)
                                }
                            }
                            ProtocolPhotoItem { photoPickerPresented = true }
                        }
                    }
                    .disabled(store.isSaving || store.importing || store.analysisID != nil)
                }
                if store.analysisID == nil && store.analysisFailed {
                    Text("일부 파일을 분석하지 못했어요. 다시 시도해 주세요.")
                        .font(.footnote)
                }
                if !store.successfulResults.isEmpty, store.analysisID == nil {
                    Button("분석 결과 보기") { showReviewConfirmation = true }
                        .buttonStyle(.labcord(.accent, size: .medium))
                }
                Button {
                    if store.selectedInputs.isEmpty {
                        store.send(.skipTapped)
                    } else {
                        showSkipConfirmation = true
                    }
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
                .disabled(store.isSaving || store.importing || store.analysisID != nil)
                .accessibilityIdentifier("entry-skip")

                EntryNextButton(
                    enabled: !store.pendingInputs.isEmpty && !store.importing
                        && !store.isSaving && store.analysisID == nil,
                    retry: store.analysisFailed,
                    action: analyze
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        }
        .overlay {
            if store.analysisID != nil {
                ProtocolAnalysisProgressView(isCancelling: store.analysisCancellationRequested) {
                    showSkipConfirmation = true
                }
                .background(Color(
                    "General/Background/Primary", bundle: LabcordDesignSystemResources.bundle
                ))
            }
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
        .alert("파일을 가져오지 못했어요", isPresented: $importFailed) {
            Button("확인", role: .cancel) { }
        } message: {
            Text("파일을 다시 선택해 주세요.")
        }
        .alert("타이머와 용어를 확인해 주세요", isPresented: $showReviewConfirmation) {
            Button("확인") { store.send(.showReview) }
            Button("취소", role: .cancel) { }
        } message: {
            Text(reviewConfirmationMessage)
        }
        .alert("분석을 건너뛸까요?", isPresented: $showSkipConfirmation) {
            Button("건너뛰기", role: .destructive) {
                if store.analysisID != nil {
                    skipAfterCancellation = true
                    store.send(.cancelAnalysis)
                    analysisTask?.cancel()
                } else {
                    store.send(.skipTapped)
                }
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("분석 결과는 초기화되고 프로토콜 없이 실험을 시작해요.")
        }
        .alert("실험 등록을 종료할까요?", isPresented: $showExitConfirmation) {
            Button("실험 등록 종료", role: .destructive) { store.send(.backTapped) }
            Button("취소", role: .cancel) { }
        } message: {
            Text("이 화면을 나가면 분석 결과가 초기화돼요.")
        }
        .photosPicker(
            isPresented: $photoPickerPresented,
            selection: $photoSelection,
            matching: .images
        )
        .onChange(of: photoSelection) { _, selection in
            importPhotos(selection)
        }
        .fileImporter(
            isPresented: $filePickerPresented,
            allowedContentTypes: protocolFileTypes
        ) { result in
            switch result {
            case let .success(url): importFile(url)
            case .failure: importFailed = true
            }
        }
        .navigationTitle("실험 등록")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar(store.analysisID == nil ? .visible : .hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("뒤로 가기", systemImage: "chevron.backward") {
                    if store.selectedInputs.isEmpty {
                        store.send(.backTapped)
                    } else {
                        showExitConfirmation = true
                    }
                }
                .disabled(store.isSaving || store.importing || store.analysisID != nil)
                .accessibilityIdentifier("entry-back")
            }
        }
    }

}

private extension ProtocolRegistrationView {
    var protocolFileTypes: [UTType] {
        [.pdf] + ["xlsx", "docx"].compactMap { UTType(filenameExtension: $0) }
    }

    var reviewConfirmationMessage: String {
        var messages: [String] = []
        if !store.pendingInputs.isEmpty {
            messages.append("분석하지 못한 파일은 제외돼요.")
        }
        if store.successfulResults.contains(where: \.hasWarnings) {
            messages.append("일부 내용을 읽지 못했을 수 있어요.")
        }
        messages.append("타이머를 확인하고 용어를 직접 입력해 주세요.")
        return messages.joined(separator: " ")
    }

    func analyze() {
        let retainedInputs = store.pendingInputs
        guard !retainedInputs.isEmpty else { return }
        let inputs = retainedInputs.map { ProtocolAnalysisInput(id: $0.id, url: $0.url) }
        let id = UUID()
        store.send(.startAnalysis(id))
        analysisTask = Task {
            defer { withExtendedLifetime(retainedInputs) {} }
            let results: [ProtocolAnalysisItem]?
            do {
                results = try await analysisClient.parse(inputs, nil)
            } catch {
                results = nil
            }
            store.send(.analysisFinished(id, results))
            analysisTask = nil
            if skipAfterCancellation {
                skipAfterCancellation = false
                store.send(.skipTapped)
            }
        }
    }

    func importPhotos(_ selection: [PhotosPickerItem]) {
        guard !selection.isEmpty else { return }
        store.send(.importStarted)
        Task {
            var failed = false
            for item in selection {
                do {
                    guard let input = try await item.loadTransferable(
                        type: ImportedProtocolInput.self
                    ) else {
                        failed = true
                        continue
                    }
                    store.send(.photoImported(input))
                } catch {
                    failed = true
                }
            }
            photoSelection = []
            store.send(.importFinished)
            importFailed = failed
        }
    }

    func importFile(_ url: URL) {
        store.send(.importStarted)
        Task {
            do {
                let input = try await ImportedProtocolInput.copyFile(url)
                store.send(.fileImported(input))
            } catch {
                importFailed = true
            }
            store.send(.importFinished)
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
    let enabled: Bool
    let retry: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(retry ? "다시 시도" : "다음")
                .font(.body)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.labcord(.primary, size: .large))
        .disabled(!enabled)
        .accessibilityIdentifier("entry-next")
    }
}
