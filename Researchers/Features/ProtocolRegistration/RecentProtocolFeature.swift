import ComposableArchitecture
import LabcordDesignSystem
import LabcordiOS
import SwiftUI

@Reducer
struct RecentProtocolFeature {
    @ObservableState
    struct State: Equatable {
        var entries: [RecentProtocolEntry] = []
        var selectedID: UUID?
        var loading = false
        var failed = false
    }

    enum Action: Equatable {
        case load
        case loaded([RecentProtocolEntry])
        case loadFailed
        case select(UUID)
        case useSelected
        case backTapped
    }

    @Dependency(\.experimentClient) var experimentClient

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .load:
                guard !state.loading else { return .none }
                state.loading = true
                state.failed = false
                return .run { send in
                    do {
                        await send(.loaded(try await experimentClient.loadRecentProtocols()))
                    } catch {
                        await send(.loadFailed)
                    }
                }
            case let .loaded(entries):
                state.loading = false
                state.entries = entries
                if !entries.contains(where: { $0.id == state.selectedID }) {
                    state.selectedID = nil
                }
                return .none
            case .loadFailed:
                state.loading = false
                state.failed = true
                return .none
            case let .select(id):
                guard state.entries.contains(where: { $0.id == id }) else { return .none }
                state.selectedID = id
                return .none
            case .useSelected, .backTapped:
                return .none
            }
        }
    }
}

struct RecentProtocolView: View {
    @Bindable var store: StoreOf<RecentProtocolFeature>
    @State private var detail: RecentProtocolEntry?

    var body: some View {
        Group {
            if store.loading {
                ProgressView("최근 프로토콜을 불러오고 있어요")
            } else if store.failed {
                ContentUnavailableView {
                    Label("프로토콜을 불러오지 못했어요", systemImage: "exclamationmark.circle")
                } actions: {
                    Button("다시 시도") { store.send(.load) }
                        .buttonStyle(.labcord(.secondary))
                }
            } else if store.entries.isEmpty {
                ContentUnavailableView("최근 사용한 프로토콜이 없어요", systemImage: "doc.text")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.entries) { entry in
                            LabcordDesignSystem.ExperimentListItem(
                                title: entry.title,
                                date: entry.createdAt.formatted(date: .numeric, time: .omitted),
                                status: .ready,
                                isSelected: Binding<Bool>(
                                    get: { store.selectedID == entry.id },
                                    set: { selected in
                                        if selected { _ = store.send(.select(entry.id)) }
                                    }
                                ),
                                showBadge: false
                            ) {
                                detail = entry
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                store.send(.useSelected)
            } label: {
                Text("다음").frame(maxWidth: .infinity)
            }
                .buttonStyle(.labcord(.primary, size: .large))
                .disabled(store.selectedID == nil || store.loading || store.failed)
                .padding(16)
        }
        .navigationTitle("최근 사용한 프로토콜")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("뒤로 가기", systemImage: "chevron.backward") {
                    store.send(.backTapped)
                }
            }
        }
        .sheet(item: $detail) { entry in
            RecentProtocolDetailView(entry: entry) {
                store.send(.select(entry.id))
                detail = nil
            }
        }
        .task { store.send(.load) }
    }
}

private struct RecentProtocolDetailView: View {
    let entry: RecentProtocolEntry
    let select: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var groups: [(String, [String])] {
        [
            ("시약·재료", entry.materials), ("샘플·분석 대상", entry.samples),
            ("실험 용어", entry.glossaryTerms), ("단위", entry.units)
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(entry.title).typography(Typography.title3)
                    Text("타이머").typography(Typography.calloutSemiBold)
                    if entry.timerSeconds.isEmpty {
                        Text("타이머가 없어요")
                    } else {
                        ForEach(Array(entry.timerSeconds.enumerated()), id: \.offset) { item in
                            let seconds = item.element
                            Text(Duration.seconds(seconds).formatted(
                                .time(pattern: .hourMinuteSecond)
                            ))
                        }
                    }
                    ForEach(groups, id: \.0) { title, terms in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(title).typography(Typography.calloutSemiBold)
                            Text(terms.isEmpty ? "용어가 없어요" : terms.joined(separator: ", "))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: select) {
                    Text("선택하기").frame(maxWidth: .infinity)
                }
                    .buttonStyle(.labcord(.primary, size: .large))
                    .padding(16)
            }
            .navigationTitle("프로토콜 상세")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }
}
