import ComposableArchitecture
import Foundation
import LabcordiOS
import LabcordShared

extension ExperimentSessionFeature {
    var completionReducer: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .stopTapped:
                guard state.canCloseSession else { return .none }
                state.isCompleting = true
                state.timer.isClosing = true
                state.completionFailed = false
                state.completionRequestedAt = now
                state.voice.isFinishingSession = true
                state.capture.video.isFinishingSession = true
                return .concatenate(
                    .send(.capture(.cancelPhotoGesture)),
                    .send(.voice(.finishForSessionEnd)),
                    .send(.capture(.video(.finishForSessionEnd))),
                    .send(.capture(.photo(.saveRequested))),
                    .send(.continueCompletion)
                )

            case .continueCompletion:
                return completeWhenMediaSaved(state: &state)

            case .voice(.saved), .capture(.video(.saved)), .capture(.photo(.saved)):
                return completeWhenMediaSaved(state: &state)

            case .capture(.photo(.captured)):
                guard state.isCompleting else { return .none }
                return .send(.capture(.photo(.saveRequested)))

            case let .voice(.saveFailed(id, _)):
                guard state.isCompleting, state.voice.recordID == id else { return .none }
                return failCompletion(state: &state)

            case let .capture(.video(.saveFailed(id, _))):
                guard state.isCompleting, state.capture.video.recordID == id else { return .none }
                return failCompletion(state: &state)

            case let .capture(.photo(.saveFailed(id, _))):
                guard state.isCompleting, state.capture.photo.recordID == id else { return .none }
                return failCompletion(state: &state)

            case let .voice(.startPermissionFailed(id, kind)):
                guard state.voice.sessionID == id else { return .none }
                let completion = state.isCompleting ? failCompletion(state: &state) : .none
                return .merge(completion, .send(.permissions(.accessFailed(kind))))

            case let .voice(.startFailed(id, _)),
                 let .voice(.event(id, .failed)),
                 let .voice(.stopped(id, nil)):
                guard state.isCompleting, state.voice.sessionID == id else { return .none }
                return failCompletion(state: &state)

            case let .capture(.video(.recordingFailed(id, _))):
                guard state.isCompleting, state.capture.video.sessionID == id else {
                    return .none
                }
                return failCompletion(state: &state)

            case .capture(.photo(.captureFailed)):
                guard state.isCompleting else { return .none }
                return failCompletion(state: &state)

            case .stopCompleted:
                guard state.isCommittingCompletion else { return .none }
                state.isCompleting = false
                state.isCommittingCompletion = false
                state.completionRequestedAt = nil
                state.voice.isFinishingSession = false
                state.capture.video.isFinishingSession = false
                return .none

            case .stopFailed:
                return failCompletion(state: &state)

            case .dismissStopFailure:
                state.completionFailed = false
                return .none
            default:
                return .none
            }
        }
    }

    func completeWhenMediaSaved(state: inout State) -> Effect<Action> {
        guard state.isCompleting, !state.isCommittingCompletion,
              let completedAt = state.completionRequestedAt,
              state.voice.phase == .hidden, !state.voice.isSaving,
              state.capture.video.phase == .idle, !state.capture.video.isSaving,
              !state.capture.photo.isCapturing, !state.capture.photo.isSaving,
              state.capture.photo.capturedData == nil else { return .none }
        state.isCommittingCompletion = true
        let experimentID = state.experimentID
        return .run { send in
            do {
                try await experimentClient.complete(experimentID, completedAt)
                await send(.stopCompleted)
            } catch {
                await send(.stopFailed)
            }
        }
    }

    func failCompletion(state: inout State) -> Effect<Action> {
        state.isCompleting = false
        state.isCommittingCompletion = false
        state.completionRequestedAt = nil
        state.voice.isFinishingSession = false
        state.capture.video.isFinishingSession = false
        state.timer.isClosing = false
        state.completionFailed = true
        return .send(.timer(.timerTick(now)))
    }

}
