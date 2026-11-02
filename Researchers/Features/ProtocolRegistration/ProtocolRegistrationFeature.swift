import ComposableArchitecture
import Foundation
import LabcordiOS

nonisolated enum ProtocolSource: String, Equatable, Sendable {
    case photos
    case file
    case recent
}

nonisolated enum ProtocolAnalysisPhase: Equatable, Sendable {
    case reading
    case extractingTerms
}

@Reducer
struct ProtocolRegistrationFeature {
    @ObservableState
    struct State: Equatable {
        var isSaving = false
        var pendingID: UUID?
        var hasFailed = false
        var importing = false
        var importedPhotos: [ImportedProtocolInput] = []
        var importedFile: ImportedProtocolInput?
        var analysisID: UUID?
        var analysisPhase = ProtocolAnalysisPhase.reading
        var analysisCancellationRequested = false
        var analysisResults: [UUID: ProtocolAnalysisItem] = [:]
        /// 분석에 성공한 문서별 추출 용어입니다. 추출에 실패한 문서는 값이 없습니다.
        var analysisTerms: [UUID: ProtocolExtractedTerms] = [:]
        var analysisFailed = false

        var selectedInputs: [ImportedProtocolInput] {
            importedPhotos + (importedFile.map { [$0] } ?? [])
        }

        var pendingInputs: [ImportedProtocolInput] {
            selectedInputs.filter { input in
                guard let item = analysisResults[input.id] else { return true }
                if case .failure = item.outcome { return true }
                return false
            }
        }

        var successfulResults: [ProtocolAnalysisItem] {
            selectedInputs.compactMap { input in
                guard let item = analysisResults[input.id], case .success = item.outcome else {
                    return nil
                }
                return item
            }
        }

        var termExtractionFailed: Bool {
            successfulResults.contains { analysisTerms[$0.id] == nil }
        }

        /// 현재 선택된 문서 중 분석에 성공한 문서의 용어를 분류별로 합칩니다.
        /// 같은 용어는 먼저 나온 분류에만 남깁니다.
        var extractedTerms: [ProtocolTermCategory: [String]] {
            var seen = Set<String>()
            var merged: [ProtocolTermCategory: [String]] = [:]
            for item in successfulResults {
                guard let terms = analysisTerms[item.id] else { continue }
                let groups: [(ProtocolTermCategory, [String])] = [
                    (.materials, terms.materials), (.samples, terms.samples),
                    (.glossary, terms.glossaryTerms), (.units, terms.units)
                ]
                for (category, values) in groups {
                    for value in values {
                        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty,
                              seen.insert(ProtocolReviewTerm.comparisonKey(trimmed)).inserted
                        else { continue }
                        merged[category, default: []].append(trimmed)
                    }
                }
            }
            return merged
        }
    }

    enum Action: Equatable {
        case backTapped
        case skipTapped
        case saved(Result<ExperimentListEntry, SaveFailure>)
        case saveSucceeded(ExperimentListEntry)
        case retryTapped
        case dismissFailure
        case sourceTapped(ProtocolSource)
        case importStarted
        case importFinished
        case photoImported(ImportedProtocolInput)
        case fileImported(ImportedProtocolInput)
        case removePhoto(UUID)
        case removeFile
        case startAnalysis(UUID)
        case analysisPhaseChanged(UUID, ProtocolAnalysisPhase)
        case cancelAnalysis
        case analysisFinished(UUID, [ProtocolAnalysisItem]?, [UUID: ProtocolExtractedTerms])
        case showReview
        case clearImportedInputs
    }

    nonisolated enum SaveFailure: Error, Equatable, Sendable {
        case saving
    }

    @Dependency(\.experimentClient) var experimentClient
    @Dependency(\.uuid) var uuid
    @Dependency(\.date.now) var now

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .backTapped:
                guard !state.importing, state.analysisID == nil else { return .none }
                state.importedPhotos = []
                state.importedFile = nil
                return .none

            case .clearImportedInputs:
                state.importedPhotos = []
                state.importedFile = nil
                return .none

            case .skipTapped:
                guard !state.isSaving, !state.hasFailed, !state.importing,
                      state.analysisID == nil else { return .none }
                let identifier = state.pendingID ?? uuid()
                state.pendingID = identifier
                state.isSaving = true
                let date = now
                return .run { send in
                    do {
                        let entry = try await experimentClient.create(identifier, date)
                        await send(.saved(.success(entry)))
                    } catch {
                        await send(.saved(.failure(.saving)))
                    }
                }

            case let .saved(result):
                guard state.isSaving else { return .none }
                state.isSaving = false
                switch result {
                case let .success(entry):
                    state.pendingID = nil
                    state.importedPhotos = []
                    state.importedFile = nil
                    return .send(.saveSucceeded(entry))
                case .failure:
                    state.hasFailed = true
                    return .none
                }

            case .retryTapped:
                state.hasFailed = false
                return .send(.skipTapped)

            case .dismissFailure:
                state.hasFailed = false
                return .none

            case .sourceTapped:
                return .none

            case .importStarted:
                state.importing = true
                return .none

            case .importFinished:
                state.importing = false
                return .none

            case let .photoImported(input):
                state.importedPhotos.append(input)
                return .none

            case let .fileImported(input):
                if let id = state.importedFile?.id { state.clearAnalysis(for: id) }
                state.importedFile = input
                return .none

            case let .removePhoto(id):
                guard let index = state.importedPhotos.firstIndex(where: { $0.id == id }) else {
                    return .none
                }
                state.importedPhotos.remove(at: index)
                state.clearAnalysis(for: id)
                return .none

            case .removeFile:
                if let id = state.importedFile?.id { state.clearAnalysis(for: id) }
                state.importedFile = nil
                return .none

            case let .startAnalysis(id):
                guard state.analysisID == nil, !state.pendingInputs.isEmpty else { return .none }
                state.analysisID = id
                state.analysisPhase = .reading
                state.analysisCancellationRequested = false
                state.analysisFailed = false
                return .none

            case let .analysisPhaseChanged(id, phase):
                guard state.analysisID == id, !state.analysisCancellationRequested else {
                    return .none
                }
                state.analysisPhase = phase
                return .none

            case .cancelAnalysis:
                guard state.analysisID != nil else { return .none }
                state.analysisCancellationRequested = true
                return .none

            case let .analysisFinished(id, items, terms):
                guard state.analysisID == id else { return .none }
                state.analysisID = nil
                state.analysisPhase = .reading
                if state.analysisCancellationRequested {
                    state.analysisCancellationRequested = false
                    return .none
                }
                guard let items else {
                    state.analysisFailed = true
                    return .none
                }
                for item in items {
                    state.analysisResults[item.id] = item
                    state.analysisTerms[item.id] = terms[item.id]
                }
                state.analysisFailed = items.contains {
                    if case .failure = $0.outcome { return true }
                    return false
                }
                return .none

            case .saveSucceeded:
                return .none

            case .showReview:
                return .none
            }
        }
    }
}

private extension ProtocolRegistrationFeature.State {
    mutating func clearAnalysis(for id: UUID) {
        analysisResults[id] = nil
        analysisTerms[id] = nil
    }
}
