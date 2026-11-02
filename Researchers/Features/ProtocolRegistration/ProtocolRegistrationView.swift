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
                if store.analysisID != nil {
                    ProgressView("프로토콜을 분석하고 있어요")
                    Button("분석 취소") {
                        store.send(.cancelAnalysis)
                        analysisTask?.cancel()
                    }
                    .disabled(store.analysisCancellationRequested)
                } else if store.analysisFailed {
                    Text("일부 파일을 분석하지 못했어요. 다시 시도해 주세요.")
                        .font(.footnote)
                }
                if !store.successfulResults.isEmpty, store.analysisID == nil {
                    Button("분석 결과 보기") { showReviewConfirmation = true }
                        .buttonStyle(.labcord(.accent, size: .medium))
                }
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
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("뒤로 가기", systemImage: "chevron.backward") {
                    store.send(.backTapped)
                }
                .disabled(store.isSaving || store.importing || store.analysisID != nil)
                .accessibilityIdentifier("entry-back")
            }
        }
    }

    private var protocolFileTypes: [UTType] {
        [.pdf] + ["xlsx", "docx"].compactMap { UTType(filenameExtension: $0) }
    }

    private var reviewConfirmationMessage: String {
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

    private func analyze() {
        let inputs = store.pendingInputs.map { ProtocolAnalysisInput(id: $0.id, url: $0.url) }
        guard !inputs.isEmpty else { return }
        let id = UUID()
        store.send(.startAnalysis(id))
        analysisTask = Task {
            let results: [ProtocolAnalysisItem]?
            do {
                results = try await analysisClient.parse(inputs, nil)
            } catch {
                results = nil
            }
            store.send(.analysisFinished(id, results))
            analysisTask = nil
        }
    }

    private func importPhotos(_ selection: [PhotosPickerItem]) {
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

    private func importFile(_ url: URL) {
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
