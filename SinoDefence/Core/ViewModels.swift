import Foundation
import Observation

/// Loads and paginates a topic list (New posts or one forum).
@MainActor
@Observable
final class TopicListModel {
    enum Mode: Hashable {
        case newPosts
        case board(BoardTarget)

        var board: BoardTarget? {
            if case .board(let board) = self { return board }
            return nil
        }

        var title: String {
            switch self {
            case .newPosts: return "New posts"
            case .board(let board): return board.name
            }
        }
    }

    private(set) var topics: [ForumTopic] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var hasMore = false
    private(set) var boardSummary: String?
    private(set) var currentPage = 1
    private(set) var pageCount = 1
    private(set) var canModerate = false
    var errorMessage: String?

    private let client = XFClient.shared
    private var mode: Mode?
    private var didLoad = false

    func loadIfNeeded(mode: Mode, session: Session) async {
        if didLoad, self.mode == mode { return }
        self.mode = mode
        await fetch(mode: mode, page: 1, session: session, appending: false)
    }

    func refresh(session: Session) async {
        guard let mode else { return }
        await fetch(mode: mode, page: 1, session: session, appending: false)
    }

    func loadMore(session: Session) async {
        guard let mode, hasMore, !isLoading, !isLoadingMore else { return }
        await fetch(mode: mode, page: currentPage + 1, session: session, appending: true)
    }

    /// Drops a topic that the user just read, without waiting for the server list.
    func removeTopic(id: Int) {
        topics.removeAll { $0.id == id }
    }

    private func fetch(mode: Mode, page: Int, session: Session, appending: Bool) async {
        if appending { isLoadingMore = true } else { isLoading = true }
        defer {
            isLoading = false
            isLoadingMore = false
        }

        #if DEBUG
        if DemoMode.isEnabled {
            apply(DemoMode.topicList(mode: mode, page: page), mode: mode, appending: appending, session: session)
            return
        }
        #endif

        do {
            let result: TopicListPage
            switch mode {
            case .newPosts:
                result = try await client.fetchNewPosts(page: page)
            case .board(let board):
                result = try await client.fetchBoard(id: board.id, slug: board.slug, page: page)
            }
            apply(result, mode: mode, appending: appending, session: session)
        } catch XFError.notLoggedIn {
            session.sessionExpired()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func apply(_ page: TopicListPage, mode: Mode, appending: Bool, session: Session) {
        if appending {
            let existing = Set(topics.map(\.id))
            topics += page.topics.filter { !existing.contains($0.id) }
        } else {
            topics = page.topics
            boardSummary = page.boardSummary
        }

        currentPage = page.currentPage
        pageCount = page.pageCount
        hasMore = page.hasNextPage
        canModerate = page.canModerate
        if page.canModerate { session.markModerator() }
        errorMessage = nil
        didLoad = true

        if case .newPosts = mode, !appending {
            session.reportNewPostsCount(topics.count)
        }
    }
}

/// Loads a thread and its posts. Unread threads open at XenForo's first-unread
/// endpoint; already-read threads open at the latest post, matching the web UI.
@MainActor
@Observable
final class TopicModel {
    let topicID: Int
    let slug: String
    /// Post the view should scroll to after the first page lands.
    private(set) var targetPostID: Int?

    private(set) var title: String
    private(set) var posts: [ForumPost] = []
    private(set) var boardName: String?
    private(set) var boardID: Int?
    private(set) var boardSlug: String?
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var hasMore = false
    private(set) var hasPrevious = false
    private(set) var isLocked = false
    private(set) var isSticky = false
    private(set) var currentPage = 1
    private(set) var pageCount = 1
    private(set) var canModerate = false
    private(set) var csrfToken: String?
    private(set) var replyURL: URL?
    private(set) var availableReactions: [ReactionOption] = []
    /// Bumped when the user jumps to another page, so the view can scroll to the top.
    private(set) var paginationToken = 0
    private(set) var jumpTarget: Int?
    private(set) var jumpToken = 0
    private(set) var isModerating = false
    var errorMessage: String?
    var moderatorMessage: String?
    var reactionMessage: String?

    private let client = XFClient.shared
    private let opensAtLatest: Bool
    private let opensAtUnread: Bool
    private let initialPostID: Int?
    private var didLoad = false

    init(topic: ForumTopic, targetPostID: Int? = nil) {
        self.initialPostID = targetPostID
        topicID = topic.id
        slug = topic.slug
        title = topic.title
        opensAtUnread = topic.isUnread
        opensAtLatest = true
        isSticky = topic.isSticky
    }

    func loadIfNeeded(session: Session) async {
        guard !didLoad else { return }
        if let initialPostID {
            await fetch(session: session, page: 1, mode: .postJump, postID: initialPostID)
        } else {
            await fetch(session: session, page: 1, mode: .initial)
        }
    }

    func refresh(session: Session) async {
        if currentPage > 1 {
            await fetch(session: session, page: currentPage, mode: .page)
        } else {
            await fetch(session: session, page: 1, mode: .initial)
        }
    }

    func loadMore(session: Session) async {
        guard hasMore, !isLoading, !isLoadingMore else { return }
        await fetch(session: session, page: currentPage + 1, mode: .append)
    }

    func loadPrevious(session: Session) async {
        guard hasPrevious, !isLoading, !isLoadingMore else { return }
        await fetch(session: session, page: max(1, currentPage - 1), mode: .prepend)
    }

    /// Jumps to a specific page (1-based), replacing the loaded posts.
    func go(to page: Int, session: Session) async {
        let target = min(max(page, 1), pageCount)
        guard target != currentPage, !isLoading, !isLoadingMore else { return }
        await fetch(session: session, page: target, mode: .page)
    }

    /// After posting, show the page containing the new post.
    func reloadAfterPost(messageID: Int?, session: Session) async {
        if let messageID {
            await fetch(session: session, page: 1, mode: .postJump, postID: messageID)
            jumpTarget = messageID
        } else {
            await fetch(session: session, page: 1, mode: .postJump, jumpToLatest: true)
            jumpTarget = posts.last?.id
        }
        jumpToken += 1
    }

    // MARK: - Reactions

    func react(_ post: ForumPost, reactionID: Int, session: Session) async {
        guard session.isSignedIn, let token = csrfToken else {
            reactionMessage = "Sign in to react to posts."
            return
        }
        do {
            let result = try await client.react(
                postID: post.id,
                reactionID: reactionID,
                csrfToken: token
            )
            guard let currentIndex = posts.firstIndex(where: { $0.id == post.id }) else { return }
            let oldReaction = posts[currentIndex].myReactionID
            if let state = result.state {
                posts[currentIndex].reactions = state.reactions
                posts[currentIndex].reactionNames = state.names
                posts[currentIndex].reactionCount = state.count
            }
            posts[currentIndex].myReactionID = result.reactionID
            posts[currentIndex].canReact = true

            if result.state == nil {
                if let newReaction = result.reactionID {
                    if oldReaction == nil {
                        posts[currentIndex].reactionCount += 1
                    }
                    if !posts[currentIndex].reactions.contains(where: { $0.id == newReaction }),
                       let option = availableReactions.first(where: { $0.id == newReaction }) {
                        posts[currentIndex].reactions.append(option)
                    }
                } else if oldReaction != nil {
                    posts[currentIndex].reactionCount = max(0, posts[currentIndex].reactionCount - 1)
                }
            }
        } catch XFError.notLoggedIn {
            session.sessionExpired()
        } catch {
            reactionMessage = error.localizedDescription
        }
    }

    // MARK: - Moderation

    func moderate(_ action: ThreadModerationAction, destinationBoardID: Int? = nil, session: Session) async -> Bool {
        guard canModerate, let token = csrfToken, !isModerating else { return false }
        isModerating = true
        defer { isModerating = false }
        do {
            let message = try await client.moderateThread(
                id: topicID,
                action: action,
                csrfToken: token,
                destinationBoardID: destinationBoardID
            )
            moderatorMessage = message
            switch action {
            case .stick: isSticky = true
            case .unstick: isSticky = false
            case .lock: isLocked = true
            case .unlock: isLocked = false
            default: break
            }
            if action == .delete {
                NotificationCenter.default.post(name: .topicDidClose, object: topicID)
                return true
            }
            await fetch(session: session, page: 1, mode: .initial)
            return true
        } catch {
            moderatorMessage = error.localizedDescription
            return false
        }
    }

    func deletePost(_ post: ForumPost, reason: String = "") async {
        guard post.canModerate, !isModerating else { return }
        isModerating = true
        defer { isModerating = false }
        do {
            try await client.deletePost(id: post.id, reason: reason)
            posts.removeAll { $0.id == post.id }
        } catch {
            moderatorMessage = error.localizedDescription
        }
    }

    // MARK: - Fetch

    private enum FetchMode {
        case initial
        case page
        case append
        case prepend
        case postJump
    }

    private func fetch(
        session: Session,
        page: Int,
        mode: FetchMode,
        postID: Int? = nil,
        jumpToLatest: Bool = false
    ) async {
        if mode == .initial || mode == .postJump {
            isLoading = true
        } else {
            isLoadingMore = true
        }
        defer {
            isLoading = false
            isLoadingMore = false
        }

        #if DEBUG
        if DemoMode.isEnabled {
            apply(DemoMode.topic(id: topicID, title: title, slug: slug, page: page), mode: mode, session: session)
            return
        }
        #endif

        do {
            let useUnread = (mode == .initial || mode == .postJump) && opensAtUnread && !jumpToLatest && postID == nil
            let useLatest = (mode == .initial || mode == .postJump) && (jumpToLatest || (opensAtLatest && !opensAtUnread)) && postID == nil
            let result = try await client.fetchThread(
                id: topicID,
                slug: slug,
                page: page,
                postID: postID,
                jumpToLatest: useLatest,
                jumpToUnread: useUnread
            )
            apply(result, mode: mode, session: session)
        } catch XFError.notLoggedIn {
            session.sessionExpired()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func apply(_ page: TopicPage, mode: FetchMode, session: Session) {
        switch mode {
        case .initial, .page, .postJump:
            posts = page.posts
            if mode == .page { paginationToken += 1 }

        case .append:
            let existing = Set(posts.map(\.id))
            posts += page.posts.filter { !existing.contains($0.id) }

        case .prepend:
            let existing = Set(posts.map(\.id))
            posts = page.posts.filter { !existing.contains($0.id) } + posts
        }

        currentPage = page.currentPage
        pageCount = max(page.pageCount, 1)
        hasMore = page.hasNextPage
        hasPrevious = page.hasPreviousPage
        if !page.title.isEmpty { title = page.title }
        boardName = page.boardName
        boardID = page.boardID
        boardSlug = page.boardSlug
        isLocked = page.isLocked
        canModerate = page.canModerate
        csrfToken = page.csrfToken
        replyURL = page.replyURL
        if !page.availableReactions.isEmpty {
            availableReactions = page.availableReactions
        }
        if canModerate { session.markModerator() }

        if let target = page.targetPostID {
            targetPostID = target
        } else if mode == .initial || mode == .postJump {
            // `/latest` has no fragment in some cases, so fall back to the last
            // post. An unread jump without a fragment should sit at the first
            // post of the page rather than hiding it.
            targetPostID = opensAtUnread ? posts.first?.id : posts.last?.id
        }

        errorMessage = nil
        didLoad = true
    }
}

extension Notification.Name {
    static let topicDidClose = Notification.Name("SinoDefence.topicDidClose")
    static let topicRead = Notification.Name("SinoDefence.topicRead")
    static let refreshNewPosts = Notification.Name("SinoDefence.refreshNewPosts")
}
