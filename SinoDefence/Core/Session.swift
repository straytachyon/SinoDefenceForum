import Foundation
import Observation

/// Owns the signed-in state, the forum structure and the shared network client.
@MainActor
@Observable
final class Session {
    enum Phase: Equatable {
        case restoring
        case signedOut
        case guest
        case signedIn
    }

    private(set) var phase: Phase = .restoring
    private(set) var user: ForumUser?
    private(set) var categories: [ForumCategory] = []
    private(set) var newPostsCount: Int?
    private(set) var isRefreshingBoards = false

    /// Message shown on the login screen (expired session, sign-out, …).
    var notice: String?
    /// Last failure while refreshing the forum structure, shown in settings.
    var boardsError: String?

    private let client = XFClient.shared
    private let keychain = KeychainStore()
    private var didBootstrap = false

    var boards: [ForumBoard] { categories.flatMap(\.boards) }
    var savedUsername: String? { keychain.load()?.username }
    var isSignedIn: Bool { phase == .signedIn }
    var isGuest: Bool { phase == .guest }
    var isModerator: Bool { user?.isModerator == true }

    /// Categories used for the tab bar. Link forums point at other sites and
    /// cannot show topics, so they are left out.
    var tabCategories: [ForumCategory] {
        categories.compactMap { category in
            let boards = category.boards.filter { !$0.isLink }
            guard !boards.isEmpty else { return nil }
            return ForumCategory(id: category.id, name: category.name, boards: boards)
        }
    }

    // MARK: - Lifecycle

    func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true

        if let cached = CacheStore.loadBoards() {
            categories = cached
        }

        #if DEBUG
        if DemoMode.isEnabled {
            let result = DemoMode.boardIndex()
            categories = result.categories
            user = ForumUser(id: 42, name: "demo_user", isModerator: true)
            newPostsCount = 20
            phase = .signedIn
            return
        }
        #endif

        do {
            if let current = try await client.fetchCurrentUser() {
                user = current
                phase = .signedIn
                UserDefaults.standard.set(false, forKey: "guestMode")
                await refreshBoards()
                await probeModerator()
                return
            }
        } catch {
            boardsError = error.localizedDescription
        }

        // The stored XenForo cookie can expire. Retry with the saved Keychain
        // credentials before dropping into guest mode.
        if let credentials = keychain.load(),
           let current = try? await client.login(username: credentials.username, password: credentials.password) {
            user = current
            phase = .signedIn
            await refreshBoards()
            await probeModerator()
            return
        }

        if UserDefaults.standard.bool(forKey: "guestMode") {
            phase = .guest
            await refreshBoards()
        } else {
            phase = .signedOut
        }
    }

    func enterGuestMode() async {
        UserDefaults.standard.set(true, forKey: "guestMode")
        user = nil
        notice = nil
        phase = .guest
        await refreshBoards()
    }

    func signIn(username: String, password: String, remember: Bool) async throws {
        let current = try await client.login(username: username, password: password)
        if remember {
            keychain.save(Credentials(username: username, password: password))
        } else {
            keychain.delete()
        }
        UserDefaults.standard.set(false, forKey: "guestMode")
        user = current
        notice = nil
        boardsError = nil
        phase = .signedIn
        await refreshBoards()
        await probeModerator()
    }

    func signOut() async {
        await client.signOut()
        keychain.delete()
        UserDefaults.standard.set(false, forKey: "guestMode")
        user = nil
        newPostsCount = nil
        boardsError = nil
        notice = "You have been signed out."
        phase = .signedOut
    }

    // MARK: - Forum structure

    func refreshBoards() async {
        guard phase != .restoring, phase != .signedOut else { return }
        #if DEBUG
        if DemoMode.isEnabled { return }
        #endif
        isRefreshingBoards = true
        defer { isRefreshingBoards = false }

        do {
            let result = try await client.fetchForumIndex()
            categories = result.categories
            boardsError = nil
            CacheStore.save(result.categories)
            if result.isModerator { markModerator() }
        } catch XFError.notLoggedIn {
            sessionExpired()
        } catch {
            boardsError = error.localizedDescription
        }
    }

    func clearCache() {
        CacheStore.clear()
        categories = []
    }

    // MARK: - Moderator

    /// The forum only exposes moderator controls on pages the account can
    /// moderate, so the app confirms the permission once and remembers it for
    /// the session. Individual thread pages refine this per thread.
    func probeModerator() async {
        guard isSignedIn, let user, user.isModerator == false else { return }
        #if DEBUG
        if DemoMode.isEnabled { return }
        #endif

        guard let page = try? await client.fetchNewPosts(page: 1) else { return }
        if page.canModerate {
            markModerator()
            return
        }

        let allowed = await client.detectModerator(
            candidates: page.topics,
            userID: user.id,
            username: user.name
        )
        if allowed { markModerator() }
    }

    func markModerator() {
        guard var current = user else { return }
        current.isModerator = true
        user = current
    }

    // MARK: - Badge / session

    func reportNewPostsCount(_ count: Int) {
        newPostsCount = count
    }

    func sessionExpired() {
        user = nil
        phase = .signedOut
        notice = "Your forum session expired. Please sign in again."
    }
}
