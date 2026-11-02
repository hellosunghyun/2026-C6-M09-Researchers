import ComposableArchitecture
import Foundation
import LabcordiOS

nonisolated enum ProtocolSource: String, Equatable, Sendable {
    case photos
    case file
    case recent
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
        var analysisCancellationRequested = false
        var analysisResults: [UUID: ProtocolAnalysisItem] = [:]
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
        case cancelAnalysis
        case analysisFinished(UUID, [ProtocolAnalysisItem]?)
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
                if let id = state.importedFile?.id { state.analysisResults[id] = nil }
                state.importedFile = input
                return .none

            case let .removePhoto(id):
                guard let index = state.importedPhotos.firstIndex(where: { $0.id == id }) else {
                    return .none
                }
                state.importedPhotos.remove(at: index)
                state.analysisResults[id] = nil
                return .none

            case .removeFile:
                if let id = state.importedFile?.id { state.analysisResults[id] = nil }
                state.importedFile = nil
                return .none

            case let .startAnalysis(id):
                guard state.analysisID == nil, !state.pendingInputs.isEmpty else { return .none }
                state.analysisID = id
                state.analysisCancellationRequested = false
                state.analysisFailed = false
                return .none

            case .cancelAnalysis:
                guard state.analysisID != nil else { return .none }
                state.analysisCancellationRequested = true
                return .none

            case let .analysisFinished(id, items):
                guard state.analysisID == id else { return .none }
                state.analysisID = nil
                if state.analysisCancellationRequested {
                    state.analysisCancellationRequested = false
                    return .none
                }
                guard let items else {
                    state.analysisFailed = true
                    return .none
                }
                for item in items { state.analysisResults[item.id] = item }
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
