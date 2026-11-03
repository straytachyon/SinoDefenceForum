import Foundation

/// Parses the server-rendered pages of XenForo 2.3 into app models.
///
/// Selectors follow XenForo's stock public templates (`forum_list`,
/// `forum_view`, `thread_view`, `whats_new_posts`). Every lookup is defensive:
/// a missing marker falls back to a looser structural query rather than failing
/// the whole page.
enum XFParser {

    // MARK: - Account

    static func parseCurrentUser(in html: String) -> ForumUser? {
        let document = HTMLParser.parse(html)
        guard document.first(where: { $0.attr("data-logged-in") == "true" }) != nil
                || capture("userId:\\s*(\\d+)", in: html).flatMap({ Int($0[1]) }).map({ $0 > 0 }) == true else {
            return nil
        }

        let memberID = capture("userId:\\s*(\\d+)", in: html).flatMap { Int($0[1]) } ?? 0

        // The account button in the header is the most reliable place to find
        // the current member's name. It links to /members/<slug>.<id>/.
        var name: String?
        var id = memberID
        let header = document.firstClass("p-navgroup--member") ?? document.firstClass("p-header")
        if let header {
            let links = header.all(where: { node in
                guard node.tag == "a", let href = node.href else { return false }
                return href.contains("/members/")
            })
            for link in links {
                let text = link.textContent
                if !text.isEmpty {
                    name = text
                    if let match = capture("/members/[^/]*\\.(\\d+)/?", in: link.href ?? ""),
                       let value = Int(match[1]) { id = value }
                    break
                }
            }
        }

        if name == nil || name?.isEmpty == true {
            let userLink = document.all(where: { node in
                node.tag == "a" && node.hasClass("p-navgroup-link--user")
            }).first
            name = userLink?.textContent
        }
        if name == nil || name?.isEmpty == true {
            name = document.firstClass("p-navgroup--member")?.firstClass("p-navgroup-linkText")?.textContent
        }

        guard id > 0 || name != nil else { return nil }
        return ForumUser(
            id: id,
            name: (name?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "Member",
            isModerator: parseIsModerator(in: document)
        )
    }

    static func parseIsModerator(in html: String) -> Bool {
        parseIsModerator(in: HTMLParser.parse(html))
    }

    static func parseIsModerator(in document: HTMLNode) -> Bool {
        if !document.all(where: { $0.hasClass("js-inlineModToggle") }).isEmpty { return true }
        if !document.all(where: { node in
            guard let initValue = node.attr("data-xf-init") else { return false }
            return initValue.split(whereSeparator: \.isWhitespace).contains("inline-mod")
        }).isEmpty { return true }
        if !document.all(where: { $0.hasClass("js-inlineModTrigger") }).isEmpty { return true }
        if document.first(where: { $0.hasClass("js-threadTools") || $0.attr("data-xf-click") == "thread-tools" }) != nil {
            return true
        }
        // A thread-tools menu links to the edit/move overlays. Ordinary members
        // do not see those links.
        if document.all(where: { node in
            guard node.tag == "a", let href = node.href else { return false }
            return capture("/threads/\\d+/(edit|move|delete)", in: href) != nil
        }).isEmpty == false {
            return true
        }
        if document.all(where: { node in
            guard node.tag == "a", let href = node.href else { return false }
            return href.hasPrefix("/admin.php") || href.contains("/admin.php?")
        }).isEmpty == false {
            return true
        }
        return false
    }

    // MARK: - Forum index

    static func parseForumIndex(_ html: String) -> BoardIndexResult {
        let document = HTMLParser.parse(html)
        var categories: [ForumCategory] = []
        var seenCategories = Set<Int>()
        var seenBoards = Set<Int>()

        let categoryBlocks = document.all(where: { node in
            node.tag == "div" && node.hasClass("block--category")
        })

        for block in categoryBlocks {
            let categoryID = categoryID(from: block)
            guard seenCategories.insert(categoryID).inserted else { continue }
            let categoryName = block.firstClass("block-header")?.firstTag("a")?.textContent
                ?? block.firstClass("block-header")?.textContent
                ?? "Forums"
            guard !categoryName.isEmpty else { continue }

            var boards: [ForumBoard] = []
            let nodeElements = block.all(where: { isForumNode($0) })
            for node in nodeElements {
                // Child forums are nested inside their parent; only top-level
                // nodes become tabs.
                if node.ancestor(where: { isForumNodeInCategory($0) }) != nil { continue }
                guard let board = parseBoardNode(node, categoryID: categoryID, categoryName: categoryName),
                      seenBoards.insert(board.id).inserted else { continue }
                boards.append(board)
            }

            if !boards.isEmpty {
                categories.append(ForumCategory(id: categoryID, name: categoryName, boards: boards))
            }
        }

        // Fallback for themes without category wrappers.
        if categories.isEmpty {
            var boards: [ForumBoard] = []
            for node in document.all(where: { isForumNode($0) }) {
                if node.ancestor(where: { isForumNode($0) }) != nil { continue }
                guard let board = parseBoardNode(node, categoryID: 0, categoryName: "Forums"),
                      seenBoards.insert(board.id).inserted else { continue }
                boards.append(board)
            }
            if !boards.isEmpty {
                categories = [ForumCategory(id: 0, name: "Forums", boards: boards)]
            }
        }

        return BoardIndexResult(
            categories: categories,
            isModerator: parseIsModerator(in: document)
        )
    }

    private static func categoryID(from block: HTMLNode) -> Int {
        for value in block.classList where value.hasPrefix("block--category") {
            let suffix = value.dropFirst("block--category".count)
            if let id = Int(suffix) { return id }
        }
        if let anchor = block.firstClass("block-header")?.firstTag("a"),
           let href = anchor.href,
           let match = capture("#[^.]+\\.(\\d+)", in: href) {
            return Int(match[1]) ?? 0
        }
        return 0
    }

    private static func isForumNode(_ node: HTMLNode) -> Bool {
        guard node.tag == "div", node.hasClass("node") else { return false }
        return node.hasClass("node--forum") || node.hasClass("node--link")
    }

    private static func isForumNodeInCategory(_ node: HTMLNode) -> Bool {
        isForumNode(node) && !node.hasClass("node--category")
    }

    private static func parseBoardNode(_ node: HTMLNode, categoryID: Int, categoryName: String) -> ForumBoard? {
        guard let idValue = node.classList.first(where: { $0.hasPrefix("node--id") }),
              let boardID = Int(idValue.dropFirst("node--id".count)) else { return nil }

        guard let titleAnchor = node.firstClass("node-title")?.firstTag("a") else { return nil }
        let name = titleAnchor.textContent
        guard !name.isEmpty else { return nil }

        let href = titleAnchor.href ?? ""
        let slug = boardSlug(from: href)
        let summary = node.firstClass("node-description")?.textContent ?? ""
        let isLink = node.hasClass("node--link") || href.contains("/link-forums/")
        let isUnread = node.hasClass("node--unread")

        var topicCount = 0
        var postCount = 0
        if let stats = node.firstClass("node-stats") ?? node.firstClass("node-statsMeta") {
            for pair in stats.all(where: { $0.tag == "dl" }) {
                let label = pair.firstTag("dt")?.textContent.lowercased() ?? ""
                let value = pair.firstTag("dd")?.textContent ?? ""
                if label.contains("thread") || label.contains("topic") {
                    topicCount = compactNumber(value) ?? 0
                } else if label.contains("message") || label.contains("post") {
                    postCount = compactNumber(value) ?? 0
                }
            }
        }

        var children: [BoardRef] = []
        for child in node.all(where: { isForumNode($0) }) {
            guard child !== node,
                  let childIDValue = child.classList.first(where: { $0.hasPrefix("node--id") }),
                  let childID = Int(childIDValue.dropFirst("node--id".count)),
                  childID != boardID else { continue }
            if child.ancestor(where: { $0 === node }) == nil { continue }
            guard let anchor = child.firstClass("node-title")?.firstTag("a") else { continue }
            let childName = anchor.textContent
            let childSlug = boardSlug(from: anchor.href ?? "")
            if childName.isEmpty || children.contains(where: { $0.id == childID }) { continue }
            children.append(BoardRef(id: childID, name: childName, slug: childSlug))
        }

        return ForumBoard(
            id: boardID,
            name: name,
            slug: slug,
            summary: summary,
            categoryID: categoryID,
            categoryName: categoryName,
            childBoards: children,
            topicCount: topicCount,
            postCount: postCount,
            isLink: isLink,
            isUnread: isUnread
        )
    }

    private static func boardSlug(from href: String) -> String {
        guard let match = capture("/f/([^/.]+)\\.(\\d+)", in: href) else { return "" }
        return match[1]
    }

    // MARK: - Topic lists (board / New posts)

    static func parseTopicList(_ html: String, pageHint: Int? = nil) -> TopicListPage {
        let document = HTMLParser.parse(html)
        let header = document.firstClass("p-body-header")
        let boardName = header?.firstClass("p-title-value")?.textContent
        let summary = header?.firstClass("p-description")?.textContent

        var topics: [ForumTopic] = []
        var seen = Set<Int>()
        for row in document.all(where: { $0.tag == "div" && $0.hasClass("structItem--thread") }) {
            guard let topic = parseTopicRow(row), seen.insert(topic.id).inserted else { continue }
            topics.append(topic)
        }

        let pagination = pagination(in: document, pageHint: pageHint)
        let boardAnchor = document.first(where: { node in
            guard node.tag == "a", let href = node.href else { return false }
            return href.contains("/f/") && (node.ancestor(where: { $0.hasClass("p-breadcrumbs") }) != nil)
        })

        return TopicListPage(
            topics: topics,
            boardID: boardAnchor.flatMap { boardID(from: $0.href ?? "") },
            boardName: boardName,
            boardSlug: boardAnchor.flatMap { boardSlug(from: $0.href ?? "") },
            boardSummary: summary,
            currentPage: pagination.current,
            pageCount: pagination.pageCount,
            totalTopics: nil,
            canModerate: parseIsModerator(in: document)
        )
    }

    private static func parseTopicRow(_ row: HTMLNode) -> ForumTopic? {
        guard let titleAnchor = row.firstClass("structItem-title")?.allTags("a").first(where: {
            ($0.href ?? "").contains("/t/") && !($0.href ?? "").contains("/latest")
        }) else { return nil }

        let href = titleAnchor.href ?? ""
        guard let match = capture("/t/[^/]*?[.-](\\d+)/", in: href),
              let topicID = Int(match[1]) else { return nil }
        let slug = threadSlug(from: href)

        let firstPart = row.firstClass("structItem-parts")
        let boardAnchor = firstPart?.all(where: { node in
            guard node.tag == "a", let link = node.href else { return false }
            return link.contains("/f/")
        }).first

        let latestCell = row.firstClass("structItem-cell--latest")
        let latestTime = latestCell?.first(where: { $0.tag == "time" })
        let lastPoster = latestCell?.all(where: { $0.tag == "a" && $0.hasClass("username") }).last?.textContent
            ?? latestCell?.firstClass("username")?.textContent
            ?? ""

        let pairValues = parsePairs(in: row)
        let repliesText = pairValues["replies"] ?? pairValues["reply"] ?? ""
        let viewsText = pairValues["views"] ?? pairValues["view"] ?? ""

        let pageJump = row.firstClass("structItem-pageJump")
        let pageCount = pageJump?.allTags("a").compactMap { anchor -> Int? in
            guard let href = anchor.href, let match = capture("/page-(\\d+)", in: href) else { return nil }
            return Int(match[1])
        }.max() ?? 1

        let isUnread = row.hasClass("is-unread")
            || row.hasClass("is-unread--highlight")
            || !row.all(where: { $0.hasClass("structItem-status--unread") }).isEmpty
            || href.contains("/unread")
        let isSticky = !row.all(where: { $0.hasClass("structItem-status--sticky") }).isEmpty
        let isLocked = !row.all(where: { $0.hasClass("structItem-status--locked") }).isEmpty

        let unwrappedHref = titleAnchor.href ?? ""
        let firstUnreadURL = unwrappedHref.contains("/unread")
            ? AppConfig.resolve(unwrappedHref)
            : nil

        return ForumTopic(
            id: topicID,
            title: titleAnchor.textContent,
            slug: slug,
            author: row.attr("data-author") ?? firstPart?.all(where: { $0.tag == "a" && $0.hasClass("username") }).first?.textContent ?? "",
            replyCount: compactNumber(repliesText) ?? 0,
            replyText: repliesText,
            viewCount: compactNumber(viewsText) ?? 0,
            viewText: viewsText,
            lastPostText: latestTime?.textContent ?? "",
            lastPostDate: latestTime.flatMap { parseDate($0.attr("datetime")) },
            lastPoster: lastPoster,
            isUnread: isUnread,
            isSticky: isSticky,
            isLocked: isLocked,
            pageCount: pageCount,
            boardID: boardAnchor.flatMap { boardID(from: $0.href ?? "") },
            boardName: boardAnchor?.textContent,
            boardSlug: boardAnchor.flatMap { boardSlug(from: $0.href ?? "") },
            lastPostID: nil,
            firstUnreadURL: firstUnreadURL
        )
    }

    private static func parsePairs(in node: HTMLNode) -> [String: String] {
        var result: [String: String] = [:]
        for pair in node.all(where: { $0.tag == "dl" }) {
            guard let label = pair.firstTag("dt")?.textContent.lowercased(),
                  let value = pair.firstTag("dd")?.textContent else { continue }
            result[label] = value
        }
        return result
    }

    // MARK: - Thread

    static func parseThread(_ html: String, topicID: Int, slug: String? = nil, pageHint: Int? = nil) -> TopicPage {
        let document = HTMLParser.parse(html)
        let title = document.firstClass("p-title-value")?.textContent
            ?? document.firstTag("title")?.textContent
            ?? ""

        let breadcrumbs = document.firstClass("p-breadcrumbs")
        let boardAnchor = breadcrumbs?.all(where: { node in
            guard node.tag == "a", let href = node.href else { return false }
            return href.contains("/f/")
        }).last

        let canonical = document.all(where: {
            $0.tag == "link" && $0.attr("rel") == "canonical"
        }).first?.attr("href")
        let resolvedSlug = slug ?? canonical.flatMap { threadSlug(from: $0) }

        let canModerate = parseIsModerator(in: document)
        var posts: [ForumPost] = []
        var seen = Set<Int>()
        for article in document.all(where: { $0.tag == "article" && $0.hasClass("message--post") }) {
            guard let post = parsePost(article, canModerate: canModerate),
                  seen.insert(post.id).inserted else { continue }
            posts.append(post)
        }

        // Some themes omit message--post but keep .js-post.
        if posts.isEmpty {
            for article in document.all(where: { $0.tag == "article" && $0.hasClass("js-post") }) {
                guard let post = parsePost(article, canModerate: canModerate),
                      seen.insert(post.id).inserted else { continue }
                posts.append(post)
            }
        }

        let pagination = pagination(in: document, pageHint: pageHint)
        let isLocked = document.first(where: { $0.hasClass("blockStatus-message--locked") }) != nil
            || document.first(where: { $0.hasClass("blockStatus-message--closed") }) != nil

        let replyForm = document.all(where: { $0.tag == "form" }).first(where: { form in
            (form.attr("action") ?? "").contains("/reply")
        })
        let replyURL = replyForm?.attr("action").flatMap { AppConfig.resolve($0) }
        let reactionTemplate = Self.capture(
            "<script[^>]*id=\"xfReactTooltipTemplate\"[^>]*>([\\s\\S]*?)</script>",
            in: html
        )?[1] ?? ""
        let availableReactions = parseReactionOptions(html: reactionTemplate)

        return TopicPage(
            topicID: topicID,
            title: normalizeTitle(title),
            slug: resolvedSlug ?? "",
            boardName: boardAnchor?.textContent,
            boardID: boardAnchor.flatMap { boardID(from: $0.href ?? "") },
            boardSlug: boardAnchor.flatMap { boardSlug(from: $0.href ?? "") },
            posts: posts,
            currentPage: pagination.current,
            pageCount: pagination.pageCount,
            isLocked: isLocked,
            isSticky: false,
            canModerate: canModerate,
            csrfToken: csrf(in: document),
            targetPostID: nil,
            replyURL: replyURL,
            availableReactions: availableReactions
        )
    }

    private static func parsePost(_ article: HTMLNode, canModerate: Bool) -> ForumPost? {
        let idText = article.attr("data-content") ?? article.id ?? ""
        guard let match = capture("post-(\\d+)", in: idText), let postID = Int(match[1]) else {
            // Fall back to the schema.org itemid: /posts/123/
            if let itemid = article.attr("itemid"), let match = capture("/posts/(\\d+)", in: itemid),
               let id = Int(match[1]) {
                return makePost(id: id, article: article, canModerate: canModerate)
            }
            return nil
        }
        return makePost(id: postID, article: article, canModerate: canModerate)
    }

    private static func makePost(id: Int, article: HTMLNode, canModerate: Bool) -> ForumPost {
        let user = article.firstClass("message-user")
        let nameAnchor = article.firstClass("message-name")?.firstTag("a")
            ?? user?.all(where: { $0.tag == "a" && $0.hasClass("username") }).first
        let author = nameAnchor?.textContent ?? article.attr("data-author") ?? "Guest"
        let authorID = nameAnchor?.attr("data-user-id").flatMap(Int.init)
            ?? nameAnchor?.href.flatMap { href -> Int? in
                guard let match = capture("\\.(\\d+)/?$", in: href) else { return nil }
                return Int(match[1])
            }

        let avatar = article.firstClass("message-avatar")?.allTags("img").first
        let avatarURL = avatar?.src.flatMap { AppConfig.resolve($0) }

        let userTitle = article.firstClass("message-userTitle")?.textContent ?? ""
        var banners: [String] = []
        for banner in article.all(where: { $0.hasClass("userBanner") }) {
            let text = banner.textContent
            if !text.isEmpty, !banners.contains(text) { banners.append(text) }
        }

        let nameClasses = Set(nameAnchor?.classList ?? [])
        let staff = !nameClasses.isDisjoint(with: ["username--staff", "username--moderator", "username--admin"])
            || nameAnchor?.all(where: { node in
                node.classList.contains("username--staff")
                    || node.classList.contains("username--moderator")
                    || node.classList.contains("username--admin")
            }).isEmpty == false

        let time = article.first(where: { $0.tag == "time" && $0.hasClass("u-dt") })
        var dateText = time?.textContent ?? ""
        if let date = time?.attr("data-date"), let clock = time?.attr("data-time"), !date.isEmpty, !clock.isEmpty {
            dateText = "\(date) at \(clock)"
        }
        let date = time.flatMap { parseDate($0.attr("datetime")) }

        let numberAnchor = article.firstClass("message-attribution-opposite")?
            .all(where: { $0.tag == "a" }).last { ($0.textContent).contains("#") }
        let postNumber = numberAnchor.flatMap { anchor -> Int? in
            guard let match = capture("#(\\d+)", in: anchor.textContent) else { return nil }
            return Int(match[1])
        }

        let body = article.firstClass("message-body")
        let contentNode = body?.firstClass("bbWrapper") ?? body
        let rawHTML = contentNode?.innerHTML ?? body?.innerHTML ?? ""
        let content = PostRenderer.render(html: rawHTML)
        let reactionState = parseReactionBar(in: article)
        let editURL = article.allTags("a").first(where: {
            let href = $0.href ?? ""
            return href.contains("/posts/\(id)/edit")
        })?.href.flatMap { AppConfig.resolve($0) }

        return ForumPost(
            id: id,
            author: author,
            authorID: authorID,
            avatarURL: avatarURL,
            userTitle: userTitle,
            banners: banners,
            isStaff: staff,
            dateText: dateText,
            date: date,
            postNumber: postNumber,
            content: content,
            rawHTML: rawHTML,
            canModerate: canModerate,
            reactions: reactionState?.reactions ?? [],
            reactionNames: reactionState?.names ?? "",
            reactionCount: reactionState?.count ?? 0,
            myReactionID: reactionState?.myReactionID,
            canReact: reactionState?.canReact ?? false,
            editURL: editURL
        )
    }

    // MARK: - Reactions

    static func parseReactionOptions(html: String) -> [ReactionOption] {
        guard !html.isEmpty else { return [] }
        let document = HTMLParser.parse(html)
        return parseReactionOptions(in: document)
    }

    private static func parseReactionOptions(in node: HTMLNode) -> [ReactionOption] {
        var result: [ReactionOption] = []
        var seen = Set<Int>()
        for anchor in node.all(where: { $0.tag == "a" || $0.tag == "span" }) {
            guard anchor.hasClass("reaction"),
                  let idText = anchor.attr("data-reaction-id"),
                  let id = Int(idText),
                  seen.insert(id).inserted else { continue }
            let image = anchor.firstTag("img")
            let name = image?.attr("alt") ?? image?.attr("title") ?? "Reaction"
            let icon = image?.src.flatMap { AppConfig.resolve($0) }
            result.append(ReactionOption(id: id, name: name, iconURL: icon))
        }
        return result.sorted { $0.id < $1.id }
    }

    private static func parseReactionBar(in article: HTMLNode) -> ReactionBarState? {
        guard let bar = article.firstClass("reactionsBar") else {
            if let link = article.all(where: {
                $0.tag == "a" && ($0.href ?? "").contains("/react?reaction_id=")
            }).first {
                let myReaction = link.hasClass("has-reaction")
                    ? link.attr("data-reaction-id").flatMap(Int.init)
                    : nil
                return ReactionBarState(
                    reactions: [],
                    names: "",
                    count: 0,
                    myReactionID: myReaction,
                    canReact: true
                )
            }
            return nil
        }

        let count = article.first(where: { $0.hasClass("message-microdata") })?
            .all(where: { $0.tag == "meta" && $0.attr("itemprop") == "userInteractionCount" })
            .first?.attr("content").flatMap(Int.init) ?? 0
        var state = reactionState(in: bar, count: count)
        if !state.canReact, let link = article.all(where: {
            $0.tag == "a" && ($0.href ?? "").contains("/react?reaction_id=")
        }).first {
            state.canReact = true
            state.myReactionID = link.hasClass("has-reaction")
                ? link.attr("data-reaction-id").flatMap(Int.init)
                : nil
        }
        return state
    }

    private static func reactionState(in bar: HTMLNode, count: Int) -> ReactionBarState {
        let reactions = parseReactionOptions(in: bar.firstClass("reactionSummary") ?? bar)
        let names = bar.firstClass("reactionsBar-link")?.textContent ?? ""
        let reactLink = bar.all(where: {
            $0.tag == "a" && ($0.href ?? "").contains("/react?reaction_id=")
        }).first
        let myReaction = reactLink?.hasClass("has-reaction") == true
            ? reactLink?.attr("data-reaction-id").flatMap(Int.init)
            : nil
        return ReactionBarState(
            reactions: reactions,
            names: names,
            count: count,
            myReactionID: myReaction,
            canReact: reactLink != nil
        )
    }

    static func parseReactionBarUpdate(_ html: String) -> ReactionBarState? {
        let document = HTMLParser.parse(html)
        guard let bar = document.firstClass("reactionsBar") else { return nil }
        let micro = document.first(where: { $0.hasClass("message-microdata") })
        let count = micro?.all(where: { $0.tag == "meta" && $0.attr("itemprop") == "userInteractionCount" })
            .first?.attr("content").flatMap(Int.init) ?? 0
        return reactionState(in: bar, count: count)
    }

    static func parseReactionMembers(_ html: String) -> [ReactionMember] {
        let document = HTMLParser.parse(html)
        let list = document.firstClass("js-reactionList-0")
            ?? document.firstClass("js-reactionTabPanes")
        guard let list else { return [] }

        var members: [ReactionMember] = []
        for (index, row) in list.all(where: { $0.tag == "li" && $0.hasClass("block-row") }).enumerated() {
            let nameAnchor = row.firstClass("contentRow-header")?.firstTag("a")
                ?? row.first(where: { $0.tag == "a" && $0.hasClass("username") })
            let name = nameAnchor?.textContent
                ?? row.firstClass("contentRow-figure")?.firstTag("img")?.attr("alt")
                ?? ""
            guard !name.isEmpty else { continue }

            let extra = row.firstClass("contentRow-extra")
            let reactionNode = extra?.all(where: { $0.hasClass("reaction") }).first
            let image = reactionNode?.firstTag("img")
            let reactionID = reactionNode?.attr("data-reaction-id").flatMap(Int.init) ?? 0
            let reaction = ReactionOption(
                id: reactionID,
                name: image?.attr("alt") ?? image?.attr("title") ?? "Reaction",
                iconURL: image?.src.flatMap { AppConfig.resolve($0) }
            )
            let avatar = row.firstClass("contentRow-figure")?.firstTag("img")?.src
                .flatMap { AppConfig.resolve($0) }
            let time = row.first(where: { $0.tag == "time" })
            let date = time?.attr("data-date") ?? time?.textContent ?? ""

            members.append(ReactionMember(
                id: "\(name)-\(index)",
                name: name,
                avatarURL: avatar,
                reaction: reaction,
                dateText: date
            ))
        }
        return members
    }

    // MARK: - Posting form

    static func parsePostForm(_ html: String, fallbackBoardID: Int? = nil, fallbackTopicID: Int? = nil) -> PostFormInfo? {
        let document = HTMLParser.parse(html)
        let form = document.all(where: { $0.tag == "form" }).first(where: { form in
            let action = form.attr("action") ?? ""
            return action.contains("/reply")
                || action.contains("/add-reply")
                || action.contains("/post-thread")
                || action.contains("/add-thread")
                || action.contains("/edit")
        })
        guard let form, let action = form.attr("action"),
              let actionURL = AppConfig.resolve(action) else { return nil }

        var fields: [String: String] = [:]
        for input in form.allTags("input") {
            guard let name = input.attr("name") else { continue }
            let type = (input.attr("type") ?? "text").lowercased()
            if ["submit", "button", "file", "image", "reset"].contains(type) { continue }
            if type == "checkbox" && input.attr("checked") == nil { continue }
            fields[name] = input.attr("value") ?? ""
        }

        let subject = form.all(where: { $0.tag == "input" && ($0.attr("name") == "title" || $0.attr("name") == "subject") })
            .first?.attr("value")
            ?? form.element(id: "title")?.attr("value")
            ?? ""
        let messageTextarea = form.allTags("textarea").first(where: { $0.attr("name") == "message_html" })
            ?? form.allTags("textarea").first(where: { $0.attr("name") == "message" })
        let message = messageTextarea?.rawText ?? ""
        let messageField = messageTextarea?.attr("name") ?? "message"

        let uploadAnchor = form.all(where: {
            $0.tag == "a" && $0.hasClass("js-attachmentUpload")
        }).first
        let attachmentUploadURL = uploadAnchor?.href.flatMap { AppConfig.resolve($0, relativeTo: actionURL) }

        let actionString = actionURL.absoluteString
        let boardID = capture("/forums/(\\d+)/", in: actionString).flatMap { Int($0[1]) }
            ?? capture("/forums/[^/]*?[.-](\\d+)/", in: actionString).flatMap { Int($0[1]) }
            ?? capture("board_id=(\\d+)", in: actionString).flatMap { Int($0[1]) }
            ?? fallbackBoardID
        let topicID = capture("/threads/(\\d+)/", in: actionString).flatMap { Int($0[1]) }
            ?? capture("/t/[^/]*?[.-](\\d+)/", in: actionString).flatMap { Int($0[1]) }
            ?? fields["thread_id"].flatMap(Int.init)
            ?? fallbackTopicID

        return PostFormInfo(
            action: actionURL,
            fields: fields,
            subject: subject,
            messageHTML: message,
            messageField: messageField,
            boardID: boardID,
            topicID: topicID,
            csrfToken: fields["_xfToken"] ?? csrf(in: document),
            attachmentUploadURL: attachmentUploadURL,
            attachmentHash: fields["attachment_hash"]
        )
    }

    // MARK: - Errors / tokens

    static func errorMessage(in html: String) -> String? {
        let document = HTMLParser.parse(html)
        for box in document.all(where: { $0.hasClass("blockMessage--error") }) {
            let text = box.textContent
            if !text.isEmpty { return text }
        }
        if let formError = document.all(where: { $0.hasClass("formRow") })
            .compactMap({ $0.firstClass("error")?.textContent })
            .first(where: { !$0.isEmpty }) {
            return formError
        }
        return nil
    }

    static func csrf(in html: String) -> String? {
        csrf(in: HTMLParser.parse(html))
    }

    static func csrf(in document: HTMLNode) -> String? {
        if let htmlNode = document.first(where: { $0.tag == "html" && $0.attr("data-csrf") != nil }),
           let token = htmlNode.attr("data-csrf") {
            return token
        }
        if let token = document.all(where: { $0.tag == "input" && $0.attr("name") == "_xfToken" }).first?.attr("value"),
           !token.isEmpty {
            return token
        }
        return nil
    }

    static func threadID(from url: URL) -> Int? {
        let text = url.absoluteString
        if let match = capture("/t/[^/]*?[.-](\\d+)", in: text) { return Int(match[1]) }
        if let match = capture("/threads/(\\d+)", in: text) { return Int(match[1]) }
        if let match = capture("[?&]thread_id=(\\d+)", in: text) { return Int(match[1]) }
        return nil
    }

    static func threadSlug(fromURL url: URL) -> String {
        threadSlug(from: url.path)
    }

    static func postID(fromRedirect url: URL) -> Int? {
        if let match = capture("/post-(\\d+)", in: url.absoluteString) {
            return Int(match[1])
        }
        if let match = capture("#post-(\\d+)", in: url.absoluteString) {
            return Int(match[1])
        }
        return nil
    }

    // MARK: - Pagination

    struct Pagination {
        var current: Int
        var pageCount: Int
    }

    static func pagination(in document: HTMLNode, pageHint: Int? = nil) -> Pagination {
        var values: [Int] = []
        if let pageNav = document.firstClass("pageNav") {
            for anchor in pageNav.allTags("a") {
                if let href = anchor.href, let match = capture("/page-(\\d+)", in: href),
                   let page = Int(match[1]) {
                    values.append(page)
                }
                if let page = Int(anchor.textContent) { values.append(page) }
            }
            for input in pageNav.allTags("input") {
                if let max = input.attr("max").flatMap(Int.init) { values.append(max) }
                if let value = input.attr("value").flatMap(Int.init) { values.append(value) }
            }
        }
        if let simple = document.firstClass("pageNavSimple-el--current")?.textContent,
           let match = capture("(\\d+)\\s+of\\s+(\\d+)", in: simple) {
            values.append(Int(match[1]) ?? 1)
            values.append(Int(match[2]) ?? 1)
        }

        var current = pageHint ?? 1
        if let currentText = document.firstClass("pageNav-page--current")?.firstTag("a")?.textContent,
           let page = Int(currentText) {
            current = page
        } else if let input = document.firstClass("pageNav")?.allTags("input").first(where: { $0.hasClass("js-pageJumpPage") }),
                  let value = input.attr("value").flatMap(Int.init) {
            current = value
        }

        let pageCount = max(values.max() ?? current, current, 1)
        return Pagination(current: max(current, 1), pageCount: pageCount)
    }

    // MARK: - Small helpers

    private static func normalizeTitle(_ value: String) -> String {
        var title = value.replacingOccurrences(of: "\u{00A0}", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // XenForo appends " | Page 2 | Forum" to the document title fallback.
        if let range = title.range(of: " | Page ") { title = String(title[..<range.lowerBound]) }
        return title
    }

    private static func threadSlug(from href: String) -> String {
        guard let match = capture("/t/([^/]+?)\\.(\\d+)(?:/|$)", in: href) else { return "" }
        return match[1]
    }

    private static func boardID(from href: String) -> Int? {
        capture("/f/[^/]*?[.-](\\d+)", in: href).flatMap { Int($0[1]) }
    }

    /// XenForo writes replies as "2K", "1.2M", "12,345" or plain digits.
    static func compactNumber(_ text: String) -> Int? {
        let cleaned = text
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        if let direct = Int(cleaned) { return direct }
        guard let match = capture("([0-9]+(?:\\.[0-9]+)?)\\s*([KkMmBb])", in: cleaned),
              let value = Double(match[1]) else { return nil }
        switch match[2].lowercased() {
        case "k": return Int(value * 1_000)
        case "m": return Int(value * 1_000_000)
        case "b": return Int(value * 1_000_000_000)
        default: return nil
        }
    }

    static func parseDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: raw) { return date }
        }
        return nil
    }

    private static func capture(_ pattern: String, in string: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(string.startIndex..., in: string)
        guard let match = regex.firstMatch(in: string, range: range) else { return nil }
        return (0..<match.numberOfRanges).map { index in
            guard let range = Range(match.range(at: index), in: string) else { return "" }
            return String(string[range])
        }
    }
}

// MARK: - Compact value display

extension XFParser {
    static func compactDisplay(_ value: Int) -> String {
        if value >= 1_000_000 { return String(format: "%.1fM", Double(value) / 1_000_000) }
        if value >= 1_000 { return String(format: "%.1fK", Double(value) / 1_000) }
        return "\(value)"
    }
}
