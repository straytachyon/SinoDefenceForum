import SwiftUI

enum TabID: Hashable {
    case newPosts
    case board(Int)
    case forums
}

/// New posts, the first three arranged boards, and a Forums directory.
///
/// Keeping the overflow inside a normal `Forums` tab rather than letting UIKit
/// create its "More" navigation controller means every board opens inside one
/// NavigationStack with one back button.
struct MainTabs: View {
    @Environment(Session.self) private var session
    @Environment(XFAlertsStore.self) private var alerts
    @Environment(\.scenePhase) private var scenePhase

    @State private var selection: TabID = .newPosts
    @State private var showSettings = false
    @State private var showAlerts = false
    @State private var unreadCount = 0
    @AppStorage(TabOrder.defaultsKey) private var tabOrder = ""

    private var orderedBoards: [ForumBoard] {
        TabOrder.ordered(session.tabCategories.flatMap(\.boards), saved: tabOrder)
    }

    /// Five tabs fit on the narrowest iPhone: New posts + three boards + Forums.
    private var directBoards: [ForumBoard] {
        Array(orderedBoards.prefix(3))
    }

    var body: some View {
        tabs
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .task {
                await refreshUnreadCount()
                await alerts.refresh(session: session)
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(90))
                    guard !Task.isCancelled else { return }
                    await alerts.refresh(session: session)
                }
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await alerts.refresh(session: session) }
            }
            .onChange(of: session.phase) { _, phase in
                if phase == .signedIn {
                    Task { await refreshUnreadCount() }
                }
            }
            .onChange(of: session.categories) { _, _ in
                validateSelection()
            }
            .onReceive(NotificationCenter.default.publisher(for: .topicRead)) { _ in
                guard session.isSignedIn else { return }
                if unreadCount > 0 { unreadCount -= 1 }
                Task {
                    try? await Task.sleep(for: .seconds(1.2))
                    await refreshUnreadCount()
                }
            }
    }

    private var tabs: some View {
        TabView(selection: $selection) {
            Tab("New posts", systemImage: "dot.radiowaves.left.and.right", value: TabID.newPosts) {
                TopicListTab(mode: .newPosts, onShowSettings: { showSettings = true })
            }
            .badge(unreadCount)

            ForEach(directBoards) { board in
                Tab(board.tabTitle, systemImage: board.iconName, value: TabID.board(board.id)) {
                    TopicListTab(
                        mode: .board(BoardTarget(board: board)),
                        onShowSettings: { showSettings = true }
                    )
                }
            }

            Tab("Forums", systemImage: "square.grid.2x2", value: TabID.forums) {
                ForumsTab(onShowSettings: { showSettings = true })
            }
        }
        .modifier(SidebarTabStyle())
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-resetTabs") {
                selection = .newPosts
            }
            #endif
        }
    }

    private func refreshUnreadCount() async {
        guard session.isSignedIn else {
            unreadCount = 0
            return
        }
        do {
            let page = try await XFClient.shared.fetchAllNewPosts()
            let count = page.topics.filter(\.isUnread).count
            unreadCount = count
        } catch {
            // A failed count refresh should not disturb the tab badge; the
            // next visit or launch retries it.
        }
    }

    private func validateSelection() {
        if case .board(let id) = selection, !session.boards.contains(where: { $0.id == id }) {
            selection = .newPosts
        }
    }
}

private struct ForumsTab: View {
    var onShowSettings: () -> Void

    @Environment(Session.self) private var session
    @Environment(XFAlertsStore.self) private var alerts
    @State private var showAlerts = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(session.tabCategories) { category in
                    Section(category.name) {
                        ForEach(category.boards) { board in
                            NavigationLink(value: BoardTarget(board: board)) {
                                HStack(spacing: 12) {
                                    Image(systemName: board.iconName)
                                        .foregroundStyle(AppTheme.accent)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(board.name)
                                        if !board.summary.isEmpty {
                                            Text(board.summary)
                                                .font(.caption)
                                                .foregroundStyle(AppTheme.secondaryText)
                                                .lineLimit(2)
                                        }
                                    }
                                    Spacer(minLength: 4)
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Forums")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: BoardTarget.self) { target in
                TopicListContent(mode: .board(target), onShowSettings: onShowSettings)
                    .id(TopicListModel.Mode.board(target))
                    .navigationTitle(target.name)
                    .navigationBarTitleDisplayMode(.inline)
            }
            .navigationDestination(for: ForumTopic.self) { topic in
                TopicDetailView(topic: topic)
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
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
        }
    }
}

/// iPadOS 18+ collapses the tab bar into a sidebar.
private struct SidebarTabStyle: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            content.tabViewStyle(.sidebarAdaptable)
        } else {
            content
        }
    }
}
