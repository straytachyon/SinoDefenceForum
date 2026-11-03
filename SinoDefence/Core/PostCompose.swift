import Foundation
import Observation

/// Drives the new-thread / reply composer: XenForo form tokens, the BBCode
/// draft, a local preview and final submission as editor HTML.
struct PendingAttachment: Identifiable, Equatable {
    enum State: Equatable {
        case uploading
        case uploaded
        case failed
    }

    let id = UUID()
    var attachmentID: Int?
    var filename: String
    var byteCount: Int
    var thumbnailURL: URL?
    var state: State
    var error: String?
}

@MainActor
@Observable
final class PostComposer {
    enum Mode {
        case newTopic(BoardTarget)
        case reply(ForumTopic, quote: ForumPost?)
        case edit(ForumPost)
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
    private(set) var attachments: [PendingAttachment] = []

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
        if case .edit = mode { return "Edit Post" }
        return isNewTopic ? "New Thread" : "Reply"
    }

    var isEditing: Bool {
        if case .edit = mode { return true }
        return false
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
            && attachments.allSatisfy { $0.state == .uploaded }
    }

    var isUploadingAttachments: Bool {
        attachments.contains { $0.state == .uploading }
    }

    func uploadAttachment(filename: String, mimeType: String, data: Data, session: Session) async {
        guard let form else {
            errorMessage = "The editor is still loading. Try attaching again in a moment."
            return
        }
        guard data.count <= 50 * 1024 * 1024 else {
            errorMessage = "Attachments are limited to 50 MB in the app."
            return
        }
        guard !filename.isEmpty else { return }

        let pending = PendingAttachment(
            attachmentID: nil,
            filename: filename,
            byteCount: data.count,
            thumbnailURL: nil,
            state: .uploading,
            error: nil
        )
        attachments.append(pending)
        errorMessage = nil

        do {
            let uploaded = try await client.uploadAttachment(
                form: form,
                filename: filename,
                mimeType: mimeType,
                data: data
            )
            if let index = attachments.firstIndex(where: { $0.id == pending.id }) {
                attachments[index].attachmentID = uploaded.id
                attachments[index].filename = uploaded.filename
                attachments[index].thumbnailURL = uploaded.thumbnailURL
                attachments[index].state = .uploaded
            }
        } catch XFError.notLoggedIn {
            markFailed(pending.id, message: "Your forum session expired. Please sign in again.")
            session.sessionExpired()
        } catch {
            markFailed(pending.id, message: error.localizedDescription)
        }
    }

    func removeAttachment(_ attachment: PendingAttachment) async {
        guard attachment.state != .uploading else { return }
        if attachment.state == .uploaded, let form, let id = attachment.attachmentID {
            do {
                try await client.deleteAttachment(form: form, attachmentID: id)
            } catch {
                errorMessage = error.localizedDescription
                return
            }
        }
        attachments.removeAll { $0.id == attachment.id }
    }

    private func markFailed(_ id: UUID, message: String) {
        if let index = attachments.firstIndex(where: { $0.id == id }) {
            attachments[index].state = .failed
            attachments[index].error = message
        }
        errorMessage = message
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
            case .edit(let post):
                boardID = nil
                topicID = post.id
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
            if message.isEmpty, case .edit(let post) = mode {
                message = HTMLToBBCode.convert(post.rawHTML)
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
            case .edit(let post):
                loaded = try await client.fetchEditForm(postID: post.id)
            }

            form = loaded
            if subject.isEmpty {
                subject = isNewTopic ? "" : loaded.subject
            }
            if message.isEmpty {
                if case .reply(_, let quote?) = mode {
                    message = Self.quoteDraft(for: quote)
                } else if case .edit(let post) = mode {
                    message = HTMLToBBCode.convert(post.rawHTML)
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
