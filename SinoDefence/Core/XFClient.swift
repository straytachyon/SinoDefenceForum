import Foundation

enum XFError: LocalizedError, Equatable {
    case notLoggedIn
    case loginFailed(String)
    case http(Int)
    case parsing(String)
    case network(String)
    case postFailed(String)
    case moderationFailed(String)

    var errorDescription: String? {
        switch self {
        case .notLoggedIn:
            return "Your session has ended. Please sign in again."
        case .loginFailed(let message):
            return message
        case .http(403):
            return "The forum refused the request (403). Your account may not have permission for that action."
        case .http(429):
            return "The forum is rate-limiting requests. Please wait a moment and try again."
        case .http(503):
            return "The forum is temporarily unavailable (503). Try again shortly."
        case .http(let code):
            return "The forum returned an unexpected response (HTTP \(code))."
        case .parsing(let message):
            return "Unexpected page from the forum: \(message)"
        case .network(let message):
            return "Network error: \(message)"
        case .postFailed(let message):
            return message
        case .moderationFailed(let message):
            return message
        }
    }
}

/// Talks to Sino Defence Forum. All requests share a cookie jar so the XenForo
/// session created by the scraped login form is reused for every later page.
actor XFClient {
    static let shared = XFClient()

    private let baseURL: URL
    private let session: URLSession
    private var newPostsBase: URL?

    init(baseURL: URL = AppConfig.baseURL) {
        self.baseURL = baseURL

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.httpShouldSetCookies = true
        configuration.httpCookieStorage = .shared
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpAdditionalHeaders = [
            "User-Agent": AppConfig.userAgent,
            "Accept-Language": "en-US,en;q=0.9",
            "Accept": "text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8",
        ]
        self.session = URLSession(configuration: configuration)
    }

    // MARK: - Account

    func fetchCurrentUser() async throws -> ForumUser? {
        let (html, _) = try await get(AppConfig.url(""))
        return XFParser.parseCurrentUser(in: html)
    }

    func login(username: String, password: String) async throws -> ForumUser {
        newPostsBase = nil
        let (loginHTML, loginURL) = try await get(AppConfig.url("login/"))
        let document = HTMLParser.parse(loginHTML)

        // If the app already has a valid XenForo session, `/login/` returns a
        // "You are already logged in" message instead of a form. Treat that as
        // a successful sign-in rather than a parsing failure; this also repairs
        // an app state that was signed out while the cookie jar stayed valid.
        guard let form = document.all(where: { $0.tag == "form" }).first(where: { form in
            (form.attr("action") ?? "").contains("/login/login")
        }), let action = form.attr("action"),
              let actionURL = AppConfig.resolve(action, relativeTo: loginURL) else {
            if let existing = XFParser.parseCurrentUser(in: loginHTML) {
                return existing
            }
            do {
                if let existing = try await fetchCurrentUser() {
                    return existing
                }
            } catch {
                // Fall through to the original form-not-found error.
            }
            throw XFError.parsing("the login form could not be found")
        }

        var fields: [String: String] = [:]
        for input in form.allTags("input") {
            guard let name = input.attr("name") else { continue }
            let type = (input.attr("type") ?? "text").lowercased()
            if ["submit", "button", "image", "file", "reset"].contains(type) { continue }
            if type == "checkbox" && input.attr("checked") == nil { continue }
            fields[name] = input.attr("value") ?? ""
        }
        fields["login"] = username
        fields["password"] = password
        fields["remember"] = "1"
        if fields["_xfRedirect"] == nil { fields["_xfRedirect"] = baseURL.absoluteString }

        var request = URLRequest(url: actionURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(loginURL.absoluteString, forHTTPHeaderField: "Referer")
        request.httpBody = Self.formEncode(fields).data(using: .utf8)

        let (data, response) = try await perform(request)
        let html = Self.decode(data, response: response)

        if let message = XFParser.errorMessage(in: html) {
            throw XFError.loginFailed(message)
        }

        guard let user = XFParser.parseCurrentUser(in: html) else {
            // The forum usually redirects to the page passed in _xfRedirect.
            // Read it once more so a cookie-only login is not reported as failure.
            if let current = try? await fetchCurrentUser() {
                return current
            }
            throw XFError.loginFailed("The forum did not accept that username and password.")
        }
        return user
    }

    func signOut() async {
        newPostsBase = nil
        let storage = HTTPCookieStorage.shared
        for cookie in (storage.cookies ?? []) where cookie.domain.contains("sinodefenceforum.com") {
            storage.deleteCookie(cookie)
        }
        URLCache.shared.removeAllCachedResponses()
    }

    // MARK: - Forum structure

    func fetchForumIndex() async throws -> BoardIndexResult {
        let (html, _) = try await get(AppConfig.url(""))
        let result = XFParser.parseForumIndex(html)
        guard !result.categories.isEmpty else {
            throw XFError.parsing("no forums were found on the index page")
        }
        return result
    }

    // MARK: - Topic lists

    func fetchNewPosts(page: Int = 1) async throws -> TopicListPage {
        let target: URL
        if page <= 1 {
            target = AppConfig.url(AppConfig.newPostsPath)
        } else if let base = newPostsBase {
            target = Self.pageURL(base: base, page: page)
        } else {
            target = AppConfig.url(AppConfig.newPostsPath)
        }

        var (html, finalURL) = try await get(target)
        if page > 1, XFParser.parseTopicList(html, pageHint: page).topics.isEmpty {
            // The cache-busting id in /whats-new/posts/<id>/ can change per
            // session. Refresh the base URL and try once more.
            let (freshHTML, freshURL) = try await get(AppConfig.url(AppConfig.newPostsPath))
            newPostsBase = freshURL
            (html, finalURL) = (freshHTML, freshURL)
        }

        if page <= 1 { newPostsBase = finalURL }
        return XFParser.parseTopicList(html, pageHint: page)
    }

    func fetchBoard(id: Int, slug: String?, page: Int = 1) async throws -> TopicListPage {
        let url = AppConfig.url(AppConfig.forumPath(id: id, slug: slug, page: page))
        let (html, finalURL) = try await get(url)
        let pageHint = Self.pageNumber(from: finalURL) ?? page
        return XFParser.parseTopicList(html, pageHint: pageHint)
    }

    // MARK: - Thread

    func fetchThread(
        id: Int,
        slug: String?,
        page: Int? = nil,
        postID: Int? = nil,
        jumpToLatest: Bool = false,
        jumpToUnread: Bool = false
    ) async throws -> TopicPage {
        let path: String
        let slugPart = (slug?.isEmpty == false) ? slug! : "thread"
        if let postID {
            path = "t/\(slugPart).\(id)/post-\(postID)"
        } else if jumpToUnread {
            path = "t/\(slugPart).\(id)/unread"
        } else if jumpToLatest {
            path = "t/\(slugPart).\(id)/latest"
        } else if let page, page > 1 {
            path = "t/\(slugPart).\(id)/page-\(page)"
        } else {
            path = "t/\(slugPart).\(id)/"
        }

        let (html, finalURL) = try await get(AppConfig.url(path))
        let hint = Self.pageNumber(from: finalURL) ?? page ?? 1
        var parsed = XFParser.parseThread(html, topicID: id, slug: slug, pageHint: hint)
        parsed.targetPostID = XFParser.postID(fromRedirect: finalURL)

        guard !parsed.posts.isEmpty else {
            throw XFError.parsing("the thread had no readable posts")
        }
        return parsed
    }

    // MARK: - Posting

    func fetchReplyForm(topicID: Int, quotePostID: Int? = nil) async throws -> PostFormInfo {
        var path = "threads/\(topicID)/reply"
        if let quotePostID { path += "?quote=\(quotePostID)" }
        let (html, _) = try await get(AppConfig.url(path))
        if let message = XFParser.errorMessage(in: html) {
            if message.localizedCaseInsensitiveContains("logged") { throw XFError.notLoggedIn }
            throw XFError.postFailed(message)
        }
        guard let form = XFParser.parsePostForm(html, fallbackTopicID: topicID) else {
            throw XFError.notLoggedIn
        }
        return form
    }

    func fetchNewThreadForm(boardID: Int) async throws -> PostFormInfo {
        let (html, _) = try await get(AppConfig.url("forums/\(boardID)/post-thread"))
        if let message = XFParser.errorMessage(in: html) {
            if message.localizedCaseInsensitiveContains("logged") { throw XFError.notLoggedIn }
            throw XFError.postFailed(message)
        }
        guard let form = XFParser.parsePostForm(html, fallbackBoardID: boardID) else {
            throw XFError.notLoggedIn
        }
        return form
    }

    func submitPost(
        form: PostFormInfo,
        title: String,
        messageHTML: String
    ) async throws -> PostOutcome {
        var fields = form.fields
        fields[form.messageField] = messageHTML
        fields["_xfToken"] = form.csrfToken ?? fields["_xfToken"] ?? ""
        fields["_xfResponseType"] = "json"
        fields["_xfWithData"] = "1"
        if form.topicID != nil {
            if !title.isEmpty { fields["title"] = title }
        } else {
            fields["title"] = title
        }

        var request = URLRequest(url: form.action)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(form.action.absoluteString, forHTTPHeaderField: "Referer")
        request.httpBody = Self.formEncode(fields).data(using: .utf8)

        let (data, response) = try await perform(request)
        let text = Self.decode(data, response: response)

        if let json = Self.jsonObject(text) {
            if let status = json["status"] as? String, status == "error" {
                let errors = json["errors"] as? [String] ?? []
                let message = errors.first ?? "The forum rejected the post. Your draft is still here."
                if message.localizedCaseInsensitiveContains("log") { throw XFError.notLoggedIn }
                throw XFError.postFailed(message)
            }
            if let redirect = json["redirect"] as? String, let url = URL(string: redirect, relativeTo: form.action) {
                let topicID = Self.captureInt("threads/(\\d+)", in: url.absoluteString)
                    ?? Self.captureInt("/t/[^/]*?[.-](\\d+)", in: url.absoluteString)
                    ?? form.topicID
                return .posted(topicID: topicID, messageID: XFParser.postID(fromRedirect: url))
            }
            if json["status"] as? String == "ok" {
                return .posted(topicID: form.topicID, messageID: nil)
            }
        }

        if let message = XFParser.errorMessage(in: text) {
            if message.localizedCaseInsensitiveContains("log") { throw XFError.notLoggedIn }
            throw XFError.postFailed(message)
        }

        let finalURL = response.url ?? form.action
        let topicID = Self.captureInt("threads/(\\d+)", in: finalURL.absoluteString)
            ?? Self.captureInt("/t/[^/]*?[.-](\\d+)", in: finalURL.absoluteString)
            ?? form.topicID
        guard topicID != nil || finalURL.absoluteString.contains("/t/") else {
            throw XFError.postFailed("The forum did not accept the post. Your draft is still here.")
        }
        return .posted(topicID: topicID, messageID: XFParser.postID(fromRedirect: finalURL))
    }

    // MARK: - Attachments

    func uploadAttachment(
        form: PostFormInfo,
        filename: String,
        mimeType: String,
        data: Data
    ) async throws -> UploadedAttachment {
        guard let uploadURL = form.attachmentUploadURL else {
            throw XFError.postFailed("This editor did not expose an attachment upload endpoint.")
        }
        let token = form.csrfToken ?? form.fields["_xfToken"] ?? ""
        guard !token.isEmpty else {
            throw XFError.notLoggedIn
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        body.appendUTF8("--\(boundary)\r\n")
        let safeName = filename
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
        body.appendUTF8("Content-Disposition: form-data; name=\"upload\"; filename=\"\(safeName)\"\r\n")
        body.appendUTF8("Content-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        body.appendUTF8("\r\n--\(boundary)--\r\n")

        guard let requestURL = Self.attachmentURL(uploadURL, token: token) else {
            throw XFError.postFailed("The attachment upload URL could not be built.")
        }
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(form.action.absoluteString, forHTTPHeaderField: "Referer")
        request.httpBody = body

        let (responseData, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw XFError.network("no HTTP response")
        }
        let text = Self.decode(responseData, response: http)

        guard let json = Self.jsonObject(text) else {
            if http.statusCode == 403 { throw XFError.notLoggedIn }
            throw XFError.postFailed("The forum returned an unexpected attachment response.")
        }
        if let status = json["status"] as? String, status == "error" {
            let errors = json["errors"] as? [String] ?? []
            let message = errors.first ?? "The forum rejected the attachment."
            if message.localizedCaseInsensitiveContains("log") { throw XFError.notLoggedIn }
            throw XFError.postFailed(message)
        }
        guard let attachment = json["attachment"] as? [String: Any],
              let attachmentID = Self.intValue(attachment["attachment_id"]) else {
            throw XFError.postFailed("The forum did not return the uploaded attachment.")
        }

        let thumbnail = (attachment["thumbnail_url"] as? String).flatMap { AppConfig.resolve($0, relativeTo: uploadURL) }
        let link = (attachment["link"] as? String).flatMap { AppConfig.resolve($0, relativeTo: uploadURL) }
        return UploadedAttachment(
            id: attachmentID,
            filename: attachment["filename"] as? String ?? filename,
            thumbnailURL: thumbnail,
            link: link
        )
    }

    func deleteAttachment(form: PostFormInfo, attachmentID: Int) async throws {
        guard let uploadURL = form.attachmentUploadURL else { return }
        let token = form.csrfToken ?? form.fields["_xfToken"] ?? ""
        guard !token.isEmpty else { throw XFError.notLoggedIn }
        guard let requestURL = Self.attachmentURL(uploadURL, token: token) else { return }

        let fields: [String: String] = [
            "delete": String(attachmentID),
            "_xfToken": token,
            "_xfResponseType": "json",
            "_xfWithData": "1",
        ]
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(form.action.absoluteString, forHTTPHeaderField: "Referer")
        request.httpBody = Self.formEncode(fields).data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { return }
        let text = Self.decode(data, response: http)
        if let json = Self.jsonObject(text) {
            if let status = json["status"] as? String, status == "error" {
                let errors = json["errors"] as? [String] ?? []
                throw XFError.postFailed(errors.first ?? "The attachment could not be removed.")
            }
            if Self.intValue(json["delete"]) != nil { return }
        }
        if http.statusCode == 403 { throw XFError.notLoggedIn }
    }

    private static func attachmentURL(_ url: URL, token: String) -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        var items = components.queryItems ?? []
        items.append(URLQueryItem(name: "_xfToken", value: token))
        items.append(URLQueryItem(name: "_xfResponseType", value: "json"))
        items.append(URLQueryItem(name: "_xfWithData", value: "1"))
        components.queryItems = items
        return components.url
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
    }

    // MARK: - Moderation

    /// XenForo performs the quick thread actions through its inline moderation
    /// endpoint. The selected ids are read from the `xf_inlinemod_thread` cookie
    /// that the web UI also uses.
    func moderateThread(
        id: Int,
        action: ThreadModerationAction,
        csrfToken: String,
        destinationBoardID: Int? = nil
    ) async throws -> String {
        switch action {
        case .stick, .unstick, .lock, .unlock:
            setInlineModSelection("thread", ids: [id])
            defer { clearInlineModSelection("thread") }

            let fields: [String: String] = [
                "_xfToken": csrfToken,
                "_xfResponseType": "json",
                "_xfWithData": "1",
                "type": "thread",
                "action": action.rawValue,
            ]
            let (data, response) = try await postForm(AppConfig.url("inline-mod/"), fields: fields, referer: AppConfig.url(""))
            let text = Self.decode(data, response: response)
            try Self.checkJSONError(text)
            return action.successMessage

        case .delete:
            let fields: [String: String] = [
                "_xfToken": csrfToken,
                "_xfResponseType": "json",
                "_xfWithData": "1",
                "reason": "",
            ]
            let (data, response) = try await postForm(AppConfig.url("threads/\(id)/delete"), fields: fields,
                                                      referer: AppConfig.url("threads/\(id)/"))
            let text = Self.decode(data, response: response)
            try Self.checkJSONError(text)
            try Self.checkHTMLSuccess(text, failure: "The forum did not delete the thread.")
            return action.successMessage

        case .move:
            guard let destinationBoardID else {
                throw XFError.moderationFailed("Choose a destination forum first.")
            }
            var fields: [String: String] = [
                "_xfToken": csrfToken,
                "_xfResponseType": "json",
                "_xfWithData": "1",
                "node_id": String(destinationBoardID),
            ]
            // Ask for no redirect, matching the common moderator default.
            fields["redirect"] = "0"
            let (data, response) = try await postForm(AppConfig.url("threads/\(id)/move"), fields: fields,
                                                      referer: AppConfig.url("threads/\(id)/"))
            let text = Self.decode(data, response: response)
            try Self.checkJSONError(text)
            try Self.checkHTMLSuccess(text, failure: "The forum did not move the thread.")
            return action.successMessage
        }
    }

    func deletePost(id: Int, reason: String = "") async throws {
        guard let token = await currentCSRFToken() else {
            throw XFError.moderationFailed("The forum security token could not be read.")
        }
        let fields: [String: String] = [
            "_xfToken": token,
            "_xfResponseType": "json",
            "_xfWithData": "1",
            "reason": reason,
        ]
        let (data, response) = try await postForm(AppConfig.url("posts/\(id)/delete"), fields: fields,
                                                  referer: AppConfig.url(""))
        let text = Self.decode(data, response: response)
        try Self.checkJSONError(text)
        try Self.checkHTMLSuccess(text, failure: "The forum did not delete the post.")
    }

    /// A cheap permission probe used once after sign-in. `GET /threads/<id>/move`
    /// renders a moderator-only form, so a 200 response proves the account can
    /// moderate that thread. Threads started by the user are skipped so that an
    /// ordinary author is not mistaken for a moderator.
    func detectModerator(candidates: [ForumTopic], userID: Int, username: String) async -> Bool {
        let eligible = candidates.filter {
            $0.author.caseInsensitiveCompare(username) != .orderedSame
        }.prefix(4)

        for topic in eligible {
            var request = URLRequest(url: AppConfig.url("threads/\(topic.id)/move"))
            request.setValue(baseURL.absoluteString, forHTTPHeaderField: "Referer")
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else { continue }
                if http.statusCode == 200 {
                    let html = Self.decode(data, response: http)
                    let document = HTMLParser.parse(html)
                    if document.all(where: { $0.tag == "form" }).contains(where: {
                        ($0.attr("action") ?? "").contains("/move")
                    }) {
                        return true
                    }
                }
            } catch {
                continue
            }
        }
        return false
    }

    private func currentCSRFToken() async -> String? {
        guard let (html, _) = try? await get(AppConfig.url("")) else { return nil }
        return XFParser.csrf(in: html)
    }

    private func setInlineModSelection(_ type: String, ids: [Int]) {
        let storage = HTTPCookieStorage.shared
        let name = "xf_inlinemod_\(type)"
        for cookie in (storage.cookies ?? []) where cookie.name == name {
            storage.deleteCookie(cookie)
        }
        let properties: [HTTPCookiePropertyKey: Any] = [
            .domain: AppConfig.forumHost,
            .path: "/",
            .name: name,
            .value: ids.map(String.init).joined(separator: ","),
            .secure: "TRUE",
            .expires: Date().addingTimeInterval(300),
        ]
        if let cookie = HTTPCookie(properties: properties) {
            storage.setCookie(cookie)
        }
    }

    private func clearInlineModSelection(_ type: String) {
        let storage = HTTPCookieStorage.shared
        for cookie in (storage.cookies ?? []) where cookie.name == "xf_inlinemod_\(type)" {
            storage.deleteCookie(cookie)
        }
    }

    // MARK: - HTTP

    private func get(_ url: URL) async throws -> (String, URL) {
        var request = URLRequest(url: url)
        request.setValue(baseURL.absoluteString, forHTTPHeaderField: "Referer")
        let (data, response) = try await perform(request)
        let html = Self.decode(data, response: response)
        if let message = XFParser.errorMessage(in: html),
           message.localizedCaseInsensitiveContains("must be logged") {
            throw XFError.notLoggedIn
        }
        return (html, response.url ?? url)
    }

    private func postForm(_ url: URL, fields: [String: String], referer: URL) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(referer.absoluteString, forHTTPHeaderField: "Referer")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.httpBody = Self.formEncode(fields).data(using: .utf8)
        return try await perform(request)
    }

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var attempt = 0
        while true {
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw XFError.network("no HTTP response")
                }
                guard (200..<400).contains(http.statusCode) else {
                    if http.statusCode == 403, Self.looksLoggedOut(data: data, response: http) {
                        throw XFError.notLoggedIn
                    }
                    throw XFError.http(http.statusCode)
                }
                return (data, http)
            } catch let error as XFError {
                throw error
            } catch let error as URLError {
                if error.code == .cancelled { throw XFError.network("cancelled") }
                attempt += 1
                guard attempt < 2 else { throw XFError.network(error.localizedDescription) }
                try? await Task.sleep(for: .milliseconds(600))
            } catch {
                throw XFError.network(error.localizedDescription)
            }
        }
    }

    private static func looksLoggedOut(data: Data, response: HTTPURLResponse) -> Bool {
        guard let html = String(data: data, encoding: .utf8) else { return false }
        return html.contains("You must be logged-in") || html.contains("must be logged in")
    }

    private static func decode(_ data: Data, response: HTTPURLResponse) -> String {
        let contentType = response.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
        if contentType.contains("iso-8859-1") || contentType.contains("latin1") {
            return String(data: data, encoding: .isoLatin1) ?? ""
        }
        return String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""
    }

    private static func formEncode(_ fields: [String: String]) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return fields
            .map { key, value in
                let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
                let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
                return "\(encodedKey)=\(encodedValue)"
            }
            .sorted()
            .joined(separator: "&")
    }

    private static func pageURL(base: URL, page: Int) -> URL {
        var string = base.absoluteString
        if string.hasSuffix("/") { string.removeLast() }
        if string.contains("/page-") {
            string = string.replacingOccurrences(of: "/page-[0-9]+", with: "", options: .regularExpression)
        }
        return URL(string: string + "/page-\(page)") ?? base
    }

    private static func pageNumber(from url: URL) -> Int? {
        captureInt("/page-(\\d+)", in: url.absoluteString)
    }

    private static func jsonObject(_ text: String) -> [String: Any]? {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return object
    }

    private static func checkJSONError(_ text: String) throws {
        guard let json = jsonObject(text) else {
            if let message = XFParser.errorMessage(in: text) { throw XFError.moderationFailed(message) }
            return
        }
        if let status = json["status"] as? String, status == "error" {
            let errors = json["errors"] as? [String] ?? []
            throw XFError.moderationFailed(errors.first ?? "The forum rejected the moderation action.")
        }
    }

    private static func checkHTMLSuccess(_ text: String, failure: String) throws {
        if let message = XFParser.errorMessage(in: text) {
            throw XFError.moderationFailed(message)
        }
        if let json = jsonObject(text) {
            if let status = json["status"] as? String, status == "error" {
                throw XFError.moderationFailed("The forum rejected the moderation action.")
            }
            if let html = json["html"] as? [String: Any] {
                // A moderation confirmation overlay: the action did not run yet.
                throw XFError.moderationFailed(
                    (html["title"] as? String) ?? "The forum needs confirmation in the web interface."
                )
            }
            return
        }
        // No error marker and no error JSON means the action was accepted.
        _ = failure
    }

    static func captureInt(_ pattern: String, in string: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: string) else { return nil }
        return Int(string[range])
    }
}

// MARK: - Posting outcomes

enum PostOutcome: Sendable {
    case preview(subject: String, content: PostContent, form: PostFormInfo)
    case posted(topicID: Int?, messageID: Int?)
}


private extension Data {
    mutating func appendUTF8(_ string: String) {
        append(Data(string.utf8))
    }
}
