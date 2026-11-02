import Foundation
import Observation

struct XFAlert: Identifiable, Hashable, Sendable {
    let id: String
    var text: String
    var time: String
    var url: URL?
    var isUnread: Bool
    var markReadURL: URL?
}

struct XFAlertsSnapshot: Sendable {
    let unread: Int
    let items: [XFAlert]
    let markAllReadURL: URL?
    let csrfToken: String?
}

@MainActor
@Observable
final class XFAlertsStore {
    private(set) var unreadCount = 0
    private(set) var items: [XFAlert] = []
    private(set) var markAllReadURL: URL?
    private(set) var isLoading = false
    var errorMessage: String?

    private let client = XFClient.shared
    private var csrfToken: String?

    func refresh(session: Session) async {
        guard session.isSignedIn, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let snapshot = try await client.fetchAlerts()
            unreadCount = snapshot.unread
            items = snapshot.items
            markAllReadURL = snapshot.markAllReadURL
            csrfToken = snapshot.csrfToken
            errorMessage = nil
        } catch XFError.notLoggedIn {
            session.sessionExpired()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markRead(_ alert: XFAlert, session: Session) async {
        guard alert.isUnread, let url = alert.markReadURL, let csrfToken else { return }
        do {
            try await client.markAlertRead(url: url, csrfToken: csrfToken)
            if let index = items.firstIndex(where: { $0.id == alert.id }) {
                items[index].isUnread = false
            }
            unreadCount = max(0, unreadCount - 1)
        } catch XFError.notLoggedIn {
            session.sessionExpired()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markAllRead(session: Session) async {
        guard unreadCount > 0, let url = markAllReadURL, let csrfToken else { return }
        do {
            try await client.markAllAlertsRead(url: url, csrfToken: csrfToken)
            for index in items.indices { items[index].isUnread = false }
            unreadCount = 0
        } catch XFError.notLoggedIn {
            session.sessionExpired()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

extension XFParser {
    static func parseAlertCount(in html: String) -> Int {
        let document = HTMLParser.parse(html)
        for anchor in document.allTags("a") {
            guard let href = anchor.href, href.contains("alerts") else { continue }
            for badge in anchor.all(where: { $0.hasClass("badge") || $0.hasClass("badgeContainer") }) {
                let digits = badge.textContent.filter(\.isNumber)
                if let count = Int(digits) { return count }
            }
        }
        return 0
    }

    static func parseAlerts(in html: String) -> [XFAlert] {
        let document = HTMLParser.parse(html)
        var alerts: [XFAlert] = []
        var rows = document.all(where: { $0.hasClass("js-alert") })
        if rows.isEmpty {
            rows = document.all(where: { $0.hasClass("alert") && $0.firstTag("time") != nil })
        }

        for (index, node) in rows.enumerated() {
            guard !(node.parent?.hasClass("js-alert") ?? false) else { continue }
            guard let timeNode = node.firstTag("time")
                ?? node.all(where: { $0.hasClass("u-dt") }).first else { continue }

            let time = timeNode.textContent.trimmingCharacters(in: .whitespacesAndNewlines)
            let toggle = node.all(where: {
                $0.tag == "a" && $0.hasClass("js-alertToggle")
            }).first
            var text = (node.firstClass("alert-content") ?? node.firstClass("alert-text") ?? node)
                .textContent
                .replacingOccurrences(of: time, with: "")
            if let toggleText = toggle?.textContent {
                text = text.replacingOccurrences(of: toggleText, with: "")
            }
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }

            let link = node.allTags("a").first(where: {
                let href = $0.href ?? ""
                return (href.contains("/posts/") || href.contains("/threads/"))
                    && !$0.hasClass("js-alertToggle")
            }) ?? node.firstClass("alert-content")?.allTags("a").first

            let unread = node.hasClass("is-unread") || node.attributes["data-unread"] != nil
            let alertID = node.attr("data-alert-id") ?? "\(index)"
            alerts.append(XFAlert(
                id: alertID,
                text: text,
                time: time,
                url: link?.href.flatMap { AppConfig.resolve($0) },
                isUnread: unread,
                markReadURL: toggle?.href.flatMap { AppConfig.resolve($0) }
            ))
        }
        return alerts
    }

    static func parseAlertMarkAllURL(in html: String) -> URL? {
        let document = HTMLParser.parse(html)
        let link = document.all(where: {
            $0.tag == "a" && $0.hasClass("js-alertsMarkRead")
        }).first
        return link?.href.flatMap { AppConfig.resolve($0) }
    }

    static func parseCSRF(in html: String) -> String? {
        let document = HTMLParser.parse(html)
        return document.firstTag("html")?.attr("data-csrf")
    }
}
