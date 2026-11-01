import Foundation

enum AppConfig {
    /// The forum this client talks to. All forum requests are relative to this URL.
    static let baseURL = URL(string: "https://www.sinodefenceforum.com/")!

    static let forumName = "Sino Defence Forum"
    static let forumSubtitle = "China Military Forum"
    static let forumHost = "www.sinodefenceforum.com"
    static let forumDisplayURL = baseURL

    /// The New posts page, which replaces the "Unread" tab used by the China
    /// Defense Forum client.
    static let newPostsPath = "whats-new/posts/"

    static let userAgent =
        "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 " +
        "(KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1 SinoDefenceReader/1.0"

    /// Builds an absolute forum URL from a path or query. XenForo uses clean,
    /// path-based routes (`/f/air-force.8/`, `/t/slug.123/page-2`).
    static func url(_ path: String) -> URL {
        let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard let url = URL(string: trimmed, relativeTo: baseURL)?.absoluteURL else {
            return baseURL
        }
        return url
    }

    /// Resolves a link found in a forum page against the forum's base URL.
    static func resolve(_ href: String, relativeTo base: URL = baseURL) -> URL? {
        let trimmed = href.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("#") { return nil }
        if trimmed.lowercased().hasPrefix("javascript:") { return nil }
        guard var absolute = URL(string: trimmed, relativeTo: base)?.absoluteURL else { return nil }

        // XenForo and many of the older picture hosts still emit http:// links.
        // Upgrade the forum itself; external hosts are left alone because not all
        // of them serve HTTPS.
        if absolute.scheme == "http", (absolute.host ?? "").hasSuffix("sinodefenceforum.com"),
           var components = URLComponents(url: absolute, resolvingAgainstBaseURL: false) {
            components.scheme = "https"
            absolute = components.url ?? absolute
        }
        return absolute
    }

    static func threadPath(id: Int, slug: String? = nil, page: Int? = nil) -> String {
        let slugPart = (slug?.isEmpty == false) ? slug! : "thread"
        if let page, page > 1 { return "t/\(slugPart).\(id)/page-\(page)" }
        return "t/\(slugPart).\(id)/"
    }

    static func forumPath(id: Int, slug: String? = nil, page: Int? = nil) -> String {
        let slugPart = (slug?.isEmpty == false) ? slug! : "forum"
        if let page, page > 1 { return "f/\(slugPart).\(id)/page-\(page)" }
        return "f/\(slugPart).\(id)/"
    }
}

enum BoardIcon {
    /// Picks a sensible SF Symbol for a board based on its name.
    static func symbol(for name: String) -> String {
        let n = name.lowercased()
        func matches(_ needles: [String]) -> Bool { needles.contains { n.contains($0) } }

        if matches(["new post", "what's new", "unread"]) { return "dot.radiowaves.left.and.right" }
        if matches(["navy", "naval", "ship", "vessel", "fleet", "submarine", "marine"]) { return "sailboat" }
        if matches(["air", "aviation", "flight", "drone", "uav"]) { return "airplane" }
        if matches(["army", "land", "ground", "infantry", "tank", "armor", "artillery"]) { return "shield.lefthalf.filled" }
        if matches(["space", "rocket", "missile", "strategic"]) { return "paperplane" }
        if matches(["nuclear", "energy"]) { return "atom" }
        if matches(["cyber", "tech", "science", "research", "electronic"]) { return "cpu" }
        if matches(["econom", "trade", "industry", "business"]) { return "chart.line.uptrend.xyaxis" }
        if matches(["politic", "government", "law", "policy"]) { return "building.columns" }
        if matches(["history", "archive"]) { return "book.closed" }
        if matches(["news", "announce", "headline"]) { return "newspaper" }
        if matches(["picture", "photo", "image", "gallery"]) { return "photo.on.rectangle.angled" }
        if matches(["off topic", "general", "lounge", "chat", "member", "club"]) { return "bubble.left.and.bubble.right" }
        if matches(["feedback", "support", "help", "site"]) { return "questionmark.circle" }
        if matches(["war", "conflict", "combat"]) { return "flame" }
        if matches(["professional", "vip"]) { return "star.circle" }
        return "bubble.left.and.text.bubble.right"
    }
}
