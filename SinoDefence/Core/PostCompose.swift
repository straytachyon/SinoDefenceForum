import Foundation
import Observation

/// Drives the new-thread / reply composer: XenForo form tokens, the BBCode
/// draft, a local preview and final submission as editor HTML.
@MainActor
@Observable
final class PostComposer {
    enum Mode {
        case newTopic(BoardTarget)
        case reply(ForumTopic, quote: ForumPost?)
    }

    struct Preview {
        var subject: String
        var content: PostContent
    }

    let mode: Mode
    private(set) var form: PostFormInfo?
    private(set) var isLoading = false
    private(set) var isSubmitting = false
    private(set) var preview: Preview?

    var subject = ""
    var message = ""
    var errorMessage: String?

    private let client = XFClient.shared

    init(mode: Mode) {
        self.mode = mode
    }

    var isNewTopic: Bool {
        if case .newTopic = mode { return true }
        return false
    }

    var navigationTitle: String {
        isNewTopic ? "New Thread" : "Reply"
    }

    var topicTitle: String {
        if case .reply(let topic, _) = mode { return topic.title }
        return ""
    }

    var boardName: String? {
        if case .newTopic(let board) = mode { return board.name }
        return nil
    }

    var canSubmit: Bool {
        form != nil
            && !isSubmitting
            && !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (!isNewTopic || !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    func load(session: Session) async {
        guard form == nil, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        #if DEBUG
        if DemoMode.isEnabled {
            let boardID: Int?
            let topicID: Int?
            switch mode {
            case .newTopic(let board):
                boardID = board.id
                topicID = nil
            case .reply(let topic, _):
                boardID = nil
                topicID = topic.id
            }
            form = PostFormInfo(
                action: AppConfig.url(topicID.map { "threads/\($0)/reply" } ?? "forums/\(boardID ?? 0)/post-thread"),
                fields: ["_xfToken": "demo"],
                subject: "",
                messageHTML: "",
                boardID: boardID,
                topicID: topicID,
                csrfToken: "demo"
            )
            if message.isEmpty, case .reply(_, let quote?) = mode {
                message = Self.quoteDraft(for: quote)
            }
            errorMessage = nil
            return
        }
        #endif

        do {
            let loaded: PostFormInfo
            switch mode {
            case .newTopic(let board):
                loaded = try await client.fetchNewThreadForm(boardID: board.id)
            case .reply(let topic, let quote):
                loaded = try await client.fetchReplyForm(topicID: topic.id, quotePostID: quote?.id)
            }

            form = loaded
            if subject.isEmpty {
                subject = isNewTopic ? "" : loaded.subject
            }
            if message.isEmpty {
                if case .reply(_, let quote?) = mode {
                    message = Self.quoteDraft(for: quote)
                } else {
                    message = ""
                }
            }
            errorMessage = nil
        } catch XFError.notLoggedIn {
            errorMessage = "Your forum session expired. Please sign in again."
            session.sessionExpired()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func requestPreview(session: Session) async {
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        let html = BBCodeHTML.convert(message)
        let content = PostRenderer.render(html: html)
        if content.isEmpty {
            errorMessage = "Write something before previewing."
            return
        }
        preview = Preview(subject: subject, content: content)
        errorMessage = nil
    }

    func submit(session: Session) async -> PostOutcome? {
        guard let form, canSubmit else { return nil }
        isSubmitting = true
        defer { isSubmitting = false }

        #if DEBUG
        if DemoMode.isEnabled {
            guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return .posted(topicID: form.topicID, messageID: nil)
        }
        #endif

        do {
            let html = BBCodeHTML.convert(message)
            guard !html.isEmpty else {
                errorMessage = "Write something before posting."
                return nil
            }
            let outcome = try await client.submitPost(
                form: form,
                title: subject.trimmingCharacters(in: .whitespacesAndNewlines),
                messageHTML: html
            )
            errorMessage = nil
            return outcome
        } catch XFError.notLoggedIn {
            errorMessage = "Your forum session expired. Please sign in again."
            session.sessionExpired()
        } catch {
            errorMessage = error.localizedDescription
        }
        return nil
    }

    private static func quoteDraft(for post: ForumPost) -> String {
        var text = String(post.content.text.characters)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if text.count > 4_000 {
            text = String(text.prefix(4_000)) + "…"
        }
        text = text.replacingOccurrences(of: "[/quote]", with: "[/ quote]")
        return "[quote=\"\(post.author)\"]\n\(text)\n[/quote]\n\n"
    }
}
