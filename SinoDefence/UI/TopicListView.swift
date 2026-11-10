import SwiftUI

/// A tab's root: its own navigation stack plus topic-list destinations.
struct TopicListTab: View {
    let mode: TopicListModel.Mode
    var onShowSettings: () -> Void

    var body: some View {
        NavigationStack {
            TopicListContent(mode: mode, onShowSettings: onShowSettings)
                // Give every tab (and every pushed child forum) its own model.
                // Without this, SwiftUI can reuse one TopicListContent state
                // slot for all board tabs and every tab ends up showing the
                // threads fetched by the last one.
                .id(mode)
                .navigationTitle(mode.title)
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: ForumTopic.self) { topic in
                    TopicDetailView(topic: topic)
                }
                .navigationDestination(for: BoardTarget.self) { target in
                    TopicListContent(mode: .board(target), onShowSettings: onShowSettings)
                        .id(TopicListModel.Mode.board(target))
                        .navigationTitle(target.name)
                        .navigationBarTitleDisplayMode(.inline)
                }
        }
    }
}

/// Topic list for a forum or for New posts.
struct TopicListContent: View {
    let mode: TopicListModel.Mode
    var onShowSettings: () -> Void

    @Environment(Session.self) private var session
    @Environment(XFAlertsStore.self) private var alerts
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var model = TopicListModel()
    @State private var showAlerts = false
    @State private var showCompose = false

    var body: some View {
        Group {
            if model.isLoading && model.topics.isEmpty {
                loadingView
            } else if model.topics.isEmpty, let error = model.errorMessage {
                errorView(error)
            } else if model.topics.isEmpty {
                emptyView
            } else {
                topicList
            }
        }
        .background(Color(.systemGroupedBackground))
        .toolbar {
            if case .board(let board) = mode {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if session.isSignedIn {
                            showCompose = true
                        } else {
                            onShowSettings()
                        }
                    } label: {
                        Image(systemName: session.isSignedIn ? "square.and.pencil" : "person.crop.circle.badge.plus")
                    }
                    .accessibilityLabel(session.isSignedIn ? "New thread" : "Sign in to start a thread")
                    .disabled(board.isLink)
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    Task { await model.refresh(session: session) }
                } label: {
                    if model.isLoading {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .accessibilityLabel("Refresh topics")
                .disabled(model.isLoading)

                Button {
                    showAlerts = true
                } label: {
                    Image(systemName: "bell")
                        .overlay(alignment: .topTrailing) {
                            if alerts.unreadCount > 0 {
                                Text(alerts.unreadCount > 99 ? "99+" : "\(alerts.unreadCount)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(.red))
                                    .offset(x: 7, y: -5)
                            }
                        }
                }
                .accessibilityLabel("Notifications")

                Button(action: onShowSettings) {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
        .sheet(isPresented: $showAlerts) {
            XFAlertsView()
        }
        .sheet(isPresented: $showCompose) {
            if case .board(let board) = mode {
                ComposeView(mode: .newTopic(board)) { _ in
                    Task { await model.refresh(session: session) }
                }
            }
        }
        .task(id: mode) {
            await model.loadIfNeeded(mode: mode, session: session)
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshNewPosts)) { _ in
            guard case .newPosts = mode, !model.isLoading else { return }
            Task { await model.refresh(session: session) }
        }
        .onAppear {
            if case .newPosts = mode {
                Task { await model.refresh(session: session) }
            }
        }
    }

    private var topicList: some View {
        List {
            if sizeClass == .regular {
                Section {
                    if case .board(let board) = mode {
                        boardHeader(board)
                    } else {
                        newPostsHeader
                    }
                }
            } else if case .board(let board) = mode, !board.summary.isEmpty || !board.childBoards.isEmpty {
                Section {
                    boardHeader(board)
                }
            } else if case .newPosts = mode {
                Section {
                    newPostsHeader
                }
            }

            Section {
                ForEach(model.topics) { topic in
                    NavigationLink(value: topic) {
                        TopicRow(topic: topic, showBoard: isNewPosts)
                    }
                    .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .onAppear {
                        guard topic.id == model.topics.last?.id else { return }
                        Task { await model.loadMore(session: session) }
                    }
                }

                if model.isLoadingMore {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Loading more topics…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                } else if model.hasMore {
                    Button {
                        Task { await model.loadMore(session: session) }
                    } label: {
                        Text("Load more topics")
                            .font(.footnote.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }

            if let error = model.errorMessage, !model.topics.isEmpty {
                Section {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable {
            await model.refresh(session: session)
        }
    }

    private var isNewPosts: Bool {
        if case .newPosts = mode { return true }
        return false
    }

    private func boardHeader(_ board: BoardTarget) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if sizeClass == .regular {
                Text(board.name)
                    .font(.largeTitle.bold())
            }
            if !board.summary.isEmpty {
                Text(board.summary)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !board.childBoards.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(board.childBoards) { child in
                            NavigationLink(value: BoardTarget(ref: child)) {
                                Label(child.name, systemImage: "arrow.turn.down.right")
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 7)
                                    .background(Capsule().fill(Color(.tertiarySystemFill)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 2)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
    }

    private var newPostsHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            if sizeClass == .regular {
                Text("New posts")
                    .font(.largeTitle.bold())
            }
            Text(newPostsSubtitle)
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(.vertical, 4)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
    }

    private var newPostsSubtitle: String {
        if model.isLoading && model.topics.isEmpty { return "Checking for new posts…" }
        if model.topics.isEmpty { return "No new posts right now" }
        let count = model.topics.count
        return count == 1 ? "1 recently active thread" : "\(count) recently active threads"
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(isNewPosts ? "Checking for new posts…" : "Loading topics…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label(
                isNewPosts ? "No new posts" : "No topics yet",
                systemImage: isNewPosts ? "checkmark.circle" : "bubble.left.and.bubble.right"
            )
        } description: {
            Text(
                isNewPosts
                    ? "There has been no recent activity on the forum."
                    : "This forum does not have any threads yet."
            )
        } actions: {
            Button("Refresh") {
                Task { await model.refresh(session: session) }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Couldn’t Load Topics", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                Task { await model.refresh(session: session) }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

struct TopicRow: View {
    let topic: ForumTopic
    var showBoard: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(topic.isUnread ? AppTheme.red : Color.clear)
                .frame(width: 3)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    if topic.isSticky {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    if topic.isLocked {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(topic.title)
                        .font(.subheadline.weight(topic.isUnread ? .semibold : .regular))
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                }

                HStack(spacing: 5) {
                    if !topic.author.isEmpty {
                        Text(topic.author).lineLimit(1)
                        Text("·")
                    }
                    if showBoard, let board = topic.boardName, !board.isEmpty {
                        Text(BoardShortName.map[board] ?? board).lineLimit(1)
                        Text("·")
                    }
                    Text(topic.lastPostText).lineLimit(1)
                }
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer(minLength: 6)

            HStack(spacing: 4) {
                Image(systemName: "bubble.left")
                    .font(.caption2)
                Text(topic.repliesLabel)
                    .font(.caption.weight(.semibold).monospacedDigit())
            }
            .foregroundStyle(AppTheme.secondaryText)
            .accessibilityLabel("\(topic.replyCount) replies")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .contentShape(Rectangle())
    }
}
