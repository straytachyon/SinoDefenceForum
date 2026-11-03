import Foundation

// MARK: - Account

struct ForumUser: Codable, Equatable, Sendable {
    let id: Int
    var name: String
    /// True once the app has seen a forum page that exposes moderator controls.
    var isModerator: Bool = false
}

// MARK: - Boards

struct BoardRef: Identifiable, Hashable, Codable, Sendable {
    let id: Int
    let name: String
    var slug: String = ""
}

struct ForumBoard: Identifiable, Hashable, Codable, Sendable {
    let id: Int
    var name: String
    var slug: String
    var summary: String
    var categoryID: Int
    var categoryName: String
    var childBoards: [BoardRef]
    var topicCount: Int
    var postCount: Int
    var isLink: Bool
    var isUnread: Bool

    var iconName: String { BoardIcon.symbol(for: name) }

    /// Short label for the tab bar. iOS lays out a dozen long titles poorly on a
    /// phone, so tabs use a compact name while navigation keeps the full name.
    var tabTitle: String {
        if let known = BoardShortName.map[name] { return known }
        var candidate = name
        for separator in [",", " & ", " and "] {
            if let range = candidate.range(of: separator) {
                candidate = String(candidate[..<range.lowerBound])
            }
        }
        if candidate.count > 14 {
            candidate = String(candidate.prefix(14)).trimmingCharacters(in: .whitespaces)
        }
        return candidate.isEmpty ? name : candidate
    }
}

enum BoardShortName {
    static let map: [String: String] = [
        "Announcements": "Announce",
        "Strategic Defense": "Strategic",
        "Air Force": "Air Force",
        "Navy": "Navy",
        "Army": "Army",
        "Military History": "History",
        "Professional Discussions": "Professional",
        "Members' Club Room": "Club Room",
        "World Armed Forces": "World",
        "General Pictures": "Pictures",
        "World Military Pictures": "Mil. Pictures",
        "Feedback & Suggestions": "Feedback",
        "New posts": "New posts",
    ]
}

struct ForumCategory: Identifiable, Hashable, Codable, Sendable {
    let id: Int
    var name: String
    var boards: [ForumBoard]
}

/// A board that can be opened as a topic list. Top-level boards become tabs;
/// child boards are pushed onto the navigation stack from within a tab.
struct BoardTarget: Hashable, Sendable {
    let id: Int
    let name: String
    var slug: String
    var summary: String = ""
    var childBoards: [BoardRef] = []
    var isLink: Bool = false

    init(board: ForumBoard) {
        id = board.id
        name = board.name
        slug = board.slug
        summary = board.summary
        childBoards = board.childBoards
        isLink = board.isLink
    }

    init(ref: BoardRef, summary: String = "", childBoards: [BoardRef] = []) {
        id = ref.id
        name = ref.name
        slug = ref.slug
        self.summary = summary
        self.childBoards = childBoards
    }
}

struct BoardIndexResult: Sendable {
    var categories: [ForumCategory]
    var isModerator: Bool

    var boards: [ForumBoard] { categories.flatMap(\.boards) }
}

// MARK: - Topics

struct ForumTopic: Identifiable, Hashable, Sendable {
    let id: Int
    var title: String
    var slug: String
    var author: String
    var replyCount: Int
    var replyText: String
    var viewCount: Int
    var viewText: String
    /// XenForo's relative timestamp ("2 minutes ago"), kept for the compact row.
    var lastPostText: String
    var lastPostDate: Date?
    var lastPoster: String
    var isUnread: Bool
    var isSticky: Bool
    var isLocked: Bool
    var pageCount: Int
    var boardID: Int?
    var boardName: String?
    var boardSlug: String?
    /// XenForo's `/latest` link resolves to the exact latest post.
    var lastPostID: Int?
    /// When set, the thread row linked directly to a first-unread URL.
    var firstUnreadURL: URL?

    var repliesLabel: String {
        if !replyText.isEmpty { return replyText }
        return replyCount > 0 ? "\(replyCount)" : "0"
    }
}

struct TopicListPage: Sendable {
    var topics: [ForumTopic]
    var boardID: Int?
    var boardName: String?
    var boardSlug: String?
    var boardSummary: String?
    var currentPage: Int
    var pageCount: Int
    var totalTopics: Int?
    var canModerate: Bool

    var hasNextPage: Bool { currentPage < pageCount }
}

// MARK: - Posts

enum PostBlock: Hashable, Sendable {
    case text(AttributedString)
    case quote(header: String, text: AttributedString)
    case code(String)
    case image(URL)
    case video(String)
    case tweet(String)
}

struct YouTubeVideo: Identifiable, Hashable, Sendable {
    let id: String
    let watchURL: URL
}

struct PostContent: Hashable, Sendable {
    /// Flattened text used for search, tests and emptiness checks.
    var text: AttributedString
    /// Ordered content; code blocks and quotes are rendered as real cards.
    var blocks: [PostBlock]
    /// Attachments, rendered after the post body.
    var images: [URL]

    var isEmpty: Bool { text.characters.isEmpty && blocks.isEmpty && images.isEmpty }
}

struct ForumPost: Identifiable, Sendable {
    let id: Int
    var author: String
    var authorID: Int?
    var avatarURL: URL?
    var userTitle: String
    var banners: [String]
    var isStaff: Bool
    var dateText: String
    var date: Date?
    var postNumber: Int?
    var content: PostContent
    var rawHTML: String
    var canModerate: Bool
    var reactions: [ReactionOption] = []
    var reactionNames: String = ""
    var reactionCount: Int = 0
    var myReactionID: Int? = nil
    var canReact: Bool = false
    var editURL: URL? = nil

    var profileURL: URL? {
        guard let authorID, authorID > 0 else { return nil }
        return AppConfig.url("members/\(authorID)/")
    }

    var postURL: URL {
        AppConfig.url("posts/\(id)/")
    }
}

struct ReactionOption: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let iconURL: URL?

    var emoji: String {
        switch name.lowercased() {
        case "like": return "👍"
        case "love": return "😍"
        case "haha": return "😂"
        case "wow": return "😮"
        case "sad": return "🙁"
        case "angry": return "😡"
        default: return "👍"
        }
    }

    static let defaults: [ReactionOption] = [
        ReactionOption(id: 1, name: "Like", iconURL: URL(string: "https://cdn.jsdelivr.net/joypixels/assets/8.0/png/unicode/64/1f44d.png")),
        ReactionOption(id: 2, name: "Love", iconURL: URL(string: "https://cdn.jsdelivr.net/joypixels/assets/8.0/png/unicode/64/1f60d.png")),
        ReactionOption(id: 3, name: "Haha", iconURL: URL(string: "https://cdn.jsdelivr.net/joypixels/assets/8.0/png/unicode/64/1f923.png")),
        ReactionOption(id: 4, name: "Wow", iconURL: URL(string: "https://cdn.jsdelivr.net/joypixels/assets/8.0/png/unicode/64/1f632.png")),
        ReactionOption(id: 5, name: "Sad", iconURL: URL(string: "https://cdn.jsdelivr.net/joypixels/assets/8.0/png/unicode/64/1f641.png")),
        ReactionOption(id: 6, name: "Angry", iconURL: URL(string: "https://cdn.jsdelivr.net/joypixels/assets/8.0/png/unicode/64/1f621.png")),
    ]
}

struct ReactionBarState: Sendable {
    var reactions: [ReactionOption]
    var names: String
    var count: Int
    var myReactionID: Int?
    var canReact: Bool
}

struct ReactionMember: Identifiable, Sendable {
    let id: String
    var name: String
    var avatarURL: URL?
    var reaction: ReactionOption
    var dateText: String
}

struct ReactionResult: Sendable {
    var reactionID: Int?
    var state: ReactionBarState?
}

struct ResolvedThread: Sendable {
    var topic: ForumTopic
    var targetPostID: Int?
}

struct TopicPage: Sendable {
    var topicID: Int
    var title: String
    var slug: String
    var boardName: String?
    var boardID: Int?
    var boardSlug: String?
    var posts: [ForumPost]
    var currentPage: Int
    var pageCount: Int
    var isLocked: Bool
    var isSticky: Bool
    var canModerate: Bool
    var csrfToken: String?
    /// Set when XenForo redirected a `/latest` or `/unread` request to a post.
    var targetPostID: Int? = nil
    var replyURL: URL?
    var availableReactions: [ReactionOption] = []

    var hasNextPage: Bool { currentPage < pageCount }
    var hasPreviousPage: Bool { currentPage > 1 }
}

// MARK: - Moderation

enum ThreadModerationAction: String, Sendable {
    case stick
    case unstick
    case lock
    case unlock
    case delete
    case move

    var title: String {
        switch self {
        case .stick: return "Stick Thread"
        case .unstick: return "Unstick Thread"
        case .lock: return "Lock Thread"
        case .unlock: return "Unlock Thread"
        case .delete: return "Delete Thread"
        case .move: return "Move Thread"
        }
    }

    var successMessage: String {
        switch self {
        case .stick: return "Thread pinned."
        case .unstick: return "Thread unpinned."
        case .lock: return "Thread locked."
        case .unlock: return "Thread unlocked."
        case .delete: return "Thread deleted."
        case .move: return "Thread moved."
        }
    }
}

struct PostFormInfo: Sendable {
    var action: URL
    var fields: [String: String]
    var subject: String
    var messageHTML: String
    /// XenForo 2.2 posts the editor HTML as `message`; 2.3 renamed the editor
    /// textarea to `message_html` (the old `message` is a no-JS fallback).
    var messageField: String = "message"
    var boardID: Int?
    var topicID: Int?
    var csrfToken: String?
    var attachmentUploadURL: URL? = nil
    var attachmentHash: String? = nil
}

struct UploadedAttachment: Sendable, Equatable {
    var id: Int
    var filename: String
    var thumbnailURL: URL?
    var link: URL?
}
