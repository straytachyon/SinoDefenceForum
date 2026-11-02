import SwiftUI

/// Converts the HTML of a XenForo post into theme-aware native content.
///
/// XenForo renders its rich-text editor into `.bbWrapper` markup: paragraphs,
/// lists, links, `.bbCodeBlock--quote` and `.bbCodeBlock--code` cards. Walking
/// that markup produces selectable `AttributedString` instead of embedding a web
/// view, so posts stay fast and work in light and dark mode.
enum PostRenderer {
    static func render(html: String, baseURL: URL = AppConfig.baseURL) -> PostContent {
        let document = HTMLParser.parse(html)
        var builder = Builder(baseURL: baseURL)
        builder.walk(childrenOf: document)
        return builder.finish()
    }

    static func isImageURL(_ url: URL) -> Bool {
        let full = url.absoluteString.lowercased()
        if full.contains("/attachments/") || full.contains("/data/attachments/") {
            return true
        }
        let ext = url.pathExtension.lowercased()
        return ["jpg", "jpeg", "png", "gif", "webp", "bmp", "heic", "avif"].contains(ext)
    }

    /// Extracts the video id from an embed/watch/short URL.
    static func youTubeID(from url: URL) -> String? {
        let host = url.host?.lowercased() ?? ""
        guard host.contains("youtube.com") || host.contains("youtu.be") else { return nil }
        let components = url.pathComponents.filter { $0 != "/" }

        if host.contains("youtu.be"), let id = components.first, id.count >= 6 {
            return id
        }
        if let index = components.firstIndex(of: "embed"), index + 1 < components.count {
            return components[index + 1]
        }
        if let index = components.firstIndex(of: "shorts"), index + 1 < components.count {
            return components[index + 1]
        }
        if let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "v" })?.value, value.count >= 6 {
            return value
        }
        return nil
    }

    /// Extracts the numeric status id from x.com/twitter.com status URLs.
    static func tweetID(from url: URL) -> String? {
        let host = url.host?.lowercased() ?? ""
        guard host == "x.com" || host.hasSuffix(".x.com")
            || host == "twitter.com" || host.hasSuffix(".twitter.com") else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        if let index = parts.firstIndex(where: { $0 == "status" || $0 == "statuses" }),
           index + 1 < parts.count {
            let value = parts[index + 1]
            return value.allSatisfy(\.isNumber) ? value : nil
        }
        return nil
    }

    static func vimeoID(from url: URL) -> String? {
        guard (url.host ?? "").contains("vimeo.com") else { return nil }
        return url.pathComponents.last(where: { $0.allSatisfy(\.isNumber) })
    }

    // MARK: - Style

    struct PostFontSizeAttribute: AttributedStringKey {
        typealias Value = Double
        static let name = "postFontSize"
    }

    private struct Style {
        var bold = false
        var italic = false
        var code = false
        var quoteDepth = 0
        var listDepth = 0
        var isHeader = false
        var isSmall = false
        var link: URL?
        var color: Color?
        var size: Double?
    }

    // MARK: - Builder

    private struct Builder {
        let baseURL: URL
        var result = AttributedString()
        var blocks: [PostBlock] = []
        var images: [URL] = []
        var pendingBreaks = 0
        var style = Style()

        mutating func walk(childrenOf node: HTMLNode) {
            for child in node.children { walk(child) }
        }

        mutating func walk(_ node: HTMLNode) {
            if node.isText {
                appendText(node.text)
                return
            }

            // XenForo's inline-mod / login prompts inside a post are noise.
            if node.hasClass("blockMessage") || node.hasClass("js-extraPhrases") {
                return
            }
            if node.hasClass("bbCodeBlock-title") || node.hasClass("bbCodeBlock-expandLink") {
                return
            }

            switch node.tag {
            case "script", "style", "noscript", "head", "input", "button", "select",
                 "textarea", "svg", "form", "label", "nav":
                return

            case "br":
                ensureBreak()

            case "p", "div", "section", "article", "header", "footer", "aside",
                 "table", "tr", "ul", "ol", "dl", "fieldset":
                blockElement(node)

            case "h1", "h2", "h3", "h4", "h5", "h6":
                header(node)

            case "blockquote":
                quoteElement(node)

            case "li":
                listItem(node)

            case "pre":
                appendCodeBlock(node.rawText)

            case "hr":
                ensureBreak()
                append(text: "———", style: style)
                ensureBreak()

            case "img":
                appendInlineImage(node)

            case "iframe", "embed", "video", "audio", "source":
                if let src = node.attr("src"), let url = AppConfig.resolve(src, relativeTo: baseURL) {
                    if let id = PostRenderer.youTubeID(from: url) {
                        appendVideoBlock(id)
                    } else if url.scheme == "https" || url.scheme == "http" {
                        ensureBreak()
                        var linkStyle = style
                        linkStyle.link = url
                        append(text: url.absoluteString, style: linkStyle)
                        ensureBreak()
                    }
                }

            case "a":
                link(node)

            case "span":
                span(node)

            case "strong", "b":
                with(node, bold: true)

            case "em", "i", "cite":
                with(node, italic: true)

            case "u":
                var container = attributes(for: style)
                container.underlineStyle = .single
                append(childrenOf: node, container: container)

            case "s", "strike", "del":
                var container = attributes(for: style)
                container.strikethroughStyle = .single
                append(childrenOf: node, container: container)

            case "code", "tt":
                let saved = style
                style.code = true
                walk(childrenOf: node)
                style = saved

            case "sup", "sub":
                walk(childrenOf: node)

            case "td", "th":
                walk(childrenOf: node)
                append(text: " ", style: style)

            default:
                walk(childrenOf: node)
            }
        }

        // MARK: Elements

        private mutating func blockElement(_ node: HTMLNode) {
            // XenForo's oEmbed card for X/Twitter.
            if node.hasClass("bbOembed") {
                let site = (node.attr("data-media-site-id") ?? "").lowercased()
                if site == "twitter" || site == "x" {
                    if let key = node.attr("data-media-key"), key.allSatisfy(\.isNumber) {
                        appendTweetBlock(key)
                        return
                    }
                    if let anchor = node.first(where: { $0.tag == "a" }),
                       let href = anchor.href,
                       let url = AppConfig.resolve(href, relativeTo: baseURL),
                       let id = PostRenderer.tweetID(from: url) {
                        appendTweetBlock(id)
                        return
                    }
                }
            }

            // XenForo code card.
            if node.hasClass("bbCodeBlock--code") || node.hasClass("bbCodeCode") || node.hasClass("bbc_code") {
                appendCodeBlock(codeText(from: node))
                return
            }

            // XenForo quote / spoiler card.
            if node.hasClass("bbCodeBlock--quote") || node.hasClass("bbCodeBlock--spoiler") {
                quoteElement(node)
                return
            }

            // XenForo embedded media card.
            if node.hasClass("bbCodeBlock--embed") {
                if let iframe = node.firstTag("iframe"), let src = iframe.attr("src"),
                   let url = AppConfig.resolve(src, relativeTo: baseURL),
                   let id = PostRenderer.youTubeID(from: url) {
                    appendVideoBlock(id)
                    return
                }
                if let anchor = node.first(where: { $0.tag == "a" && $0.href != nil }),
                   let href = anchor.href, let url = AppConfig.resolve(href, relativeTo: baseURL),
                   let id = PostRenderer.youTubeID(from: url) {
                    appendVideoBlock(id)
                    return
                }
            }

            // Legacy SMF-style code captions, retained for old imported posts.
            if node.hasClass("quoteheader") || node.hasClass("codeheader") {
                ensureBreak()
                var caption = style
                caption.isSmall = true
                caption.bold = true
                append(text: node.textContent, style: caption)
                ensureBreak()
                return
            }
            if node.hasClass("quoteexpand") || node.hasClass("code_operation") {
                return
            }

            // XenForo wraps editable content in .bbWrapper.
            ensureBreak()
            walk(childrenOf: node)
            ensureBreak()
        }

        private mutating func quoteElement(_ node: HTMLNode) {
            let titleNode = node.firstClass("bbCodeBlock-title")
            var header = titleNode?.textContent ?? ""
            if header.isEmpty {
                if node.hasClass("bbCodeBlock--spoiler") {
                    header = "Spoiler"
                } else if let quote = node.attr("data-quote"), !quote.isEmpty {
                    header = "\(quote) said:"
                } else {
                    header = "Quote"
                }
            }
            header = header.trimmingCharacters(in: .whitespacesAndNewlines)

            let content = node.firstClass("bbCodeBlock-expandContent")
                ?? node.firstClass("bbCodeBlock-content")

            guard let content else { return }
            var nested = Builder(baseURL: baseURL)
            nested.style.quoteDepth = style.quoteDepth + 1
            nested.style.italic = false
            nested.walk(childrenOf: content)
            nested.flushTextBlock()

            var quoteText = AttributedString()
            for block in nested.blocks {
                switch block {
                case .text(let text):
                    quoteText += text
                case .quote(_, let text):
                    if !quoteText.characters.isEmpty { quoteText += AttributedString("\n") }
                    quoteText += text
                case .code(let code):
                    if !quoteText.characters.isEmpty { quoteText += AttributedString("\n") }
                    quoteText += AttributedString(code)
                case .image(let url):
                    if !images.contains(url) { images.append(url) }
                case .video, .tweet:
                    break
                }
            }

            let trimmed = quoteText.characters.isEmpty ? "" : String(quoteText.characters)
            guard !trimmed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

            flushTextBlock()
            pendingBreaks = 0
            let block = PostBlock.quote(header: header, text: quoteText)
            if !blocks.contains(block) { blocks.append(block) }
        }

        private func codeText(from node: HTMLNode) -> String {
            let code = node.firstClass("bbCodeCode")?.firstTag("code")
                ?? node.firstClass("bbCodeCode")
                ?? node.firstClass("bbCodeBlock-content")
                ?? node
            return code.rawText
        }

        private mutating func header(_ node: HTMLNode) {
            let saved = style
            style.bold = true
            style.isHeader = true
            ensureBreak()
            walk(childrenOf: node)
            ensureBreak()
            style = saved
        }

        private mutating func listItem(_ node: HTMLNode) {
            ensureBreak()
            let parentIsOrdered = node.parent?.tag == "ol"
            append(text: parentIsOrdered ? "•  " : "•  ", style: style)
            let saved = style
            style.listDepth += 1
            walk(childrenOf: node)
            style = saved
            ensureBreak()
        }

        private mutating func link(_ node: HTMLNode) {
            guard let href = node.attr("href"), let url = AppConfig.resolve(href, relativeTo: baseURL) else {
                walk(childrenOf: node)
                return
            }

            // Expand bare X/Twitter status links into an inline card. Custom
            // link text stays a normal link.
            if let id = PostRenderer.tweetID(from: url) {
                let text = node.textContent.trimmingCharacters(in: .whitespacesAndNewlines)
                let bare = text.isEmpty
                    || text.lowercased().hasPrefix("http")
                    || text.lowercased().contains("twitter.com/")
                    || text.lowercased().contains("x.com/")
                if bare {
                    appendTweetBlock(id)
                    return
                }
            }

            // A YouTube URL that is the whole content of a link is a video, not
            // prose. XenForo stores some embeds this way.
            if let id = PostRenderer.youTubeID(from: url),
               node.textContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || node.allTags("img").isEmpty == false && node.textContent.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 {
                appendVideoBlock(id)
                return
            }

            // XenForo wraps pictures in a link to the attachment. The <img> URL is
            // the direct file, so use it unless the link itself is an image file.
            if let image = node.allTags("img").first {
                // XenForo's attachment links look like
                // `/attachments/name-jpg.179560/` and resolve to an HTML page,
                // not an image. Only prefer the href when it is an actual
                // image file; otherwise the <img> src is the direct file.
                let ext = url.pathExtension.lowercased()
                let directImage = ["jpg", "jpeg", "png", "gif", "webp", "bmp", "heic", "avif"].contains(ext)
                    || url.absoluteString.lowercased().contains(";image")
                appendInlineImage(image, preferredURL: directImage ? url : nil)
                return
            }

            let saved = style
            style.link = url
            walk(childrenOf: node)
            style = saved
        }

        private mutating func with(_ node: HTMLNode, bold: Bool = false, italic: Bool = false) {
            let saved = style
            if bold { style.bold = true }
            if italic { style.italic = true }
            walk(childrenOf: node)
            style = saved
        }

        private mutating func span(_ node: HTMLNode) {
            let saved = style
            if let raw = node.attr("style") {
                if let color = Self.inlineColor(raw) { style.color = color }
                if let size = Self.inlineFontSize(raw) { style.size = size }
            }
            if node.hasClass("bbCodeInline") {
                style.code = true
            }
            walk(childrenOf: node)
            style = saved
        }

        private static func inlineColor(_ style: String) -> Color? {
            guard let range = style.range(of: "color\\s*:", options: .regularExpression) else { return nil }
            let rest = style[range.upperBound...]
            let value = rest.split(separator: ";").first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return color(named: value)
        }

        private static func inlineFontSize(_ style: String) -> Double? {
            guard let range = style.range(of: "font-size\\s*:", options: .regularExpression) else { return nil }
            let rest = style[range.upperBound...]
            let value = rest.split(separator: ";").first?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "px", with: "") ?? ""
            return Double(value)
        }

        private static func color(named value: String) -> Color? {
            let name = value.lowercased()
            if name.hasPrefix("#") {
                let hex = String(name.dropFirst())
                guard hex.count == 6, let number = Int(hex, radix: 16) else { return nil }
                return Color(
                    red: Double((number >> 16) & 0xFF) / 255,
                    green: Double((number >> 8) & 0xFF) / 255,
                    blue: Double(number & 0xFF) / 255
                )
            }
            switch name {
            case "blue": return .blue
            case "red": return .red
            case "green": return .green
            case "orange": return .orange
            case "purple": return .purple
            case "gray", "grey": return .gray
            case "brown": return .brown
            case "cyan": return .cyan
            case "magenta": return .pink
            case "yellow": return .yellow
            case "black": return .black
            case "white": return .white
            default: return nil
            }
        }

        private mutating func appendInlineImage(_ node: HTMLNode, preferredURL: URL? = nil) {
            // XenForo sometimes writes data-url="" on an attachment <img> whose
            // usable URL is the src or the wrapper's data-src. `??` is not
            // enough here: an empty attribute still wins over a later fallback.
            let candidates = [
                node.attr("data-url"),
                node.parent?.attr("data-src"),
                node.attr("data-src"),
                node.attr("src"),
            ]
            let source = candidates
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first { !$0.isEmpty }
            guard let source,
                  var url = preferredURL ?? AppConfig.resolve(source, relativeTo: baseURL),
                  url.scheme == "https" || url.scheme == "http" else { return }

            if node.hasClass("smilie") || node.hasClass("smiley") { return }
            let path = url.path.lowercased()
            if path.contains("/smileys/") || path.contains("/styles/") || path.contains("/js/") { return }
            if path.hasSuffix(".svg") { return }
            // XenForo marks post pictures with .bbImage (usually inside a
            // .bbImageWrapper). Many modern hosts use extension-less URLs such
            // as pbs.twimg.com/media/…?format=jpg, so the class is a stronger
            // signal than the file extension.
            let markedImage = node.hasClass("bbImage")
                || node.ancestor(where: { $0.hasClass("bbImageWrapper") }) != nil
            if !markedImage, !PostRenderer.isImageURL(url), !path.contains("/data/attachments/") { return }

            // Some attachment thumbnails carry a cache-busting query; keep as is.
            if url.absoluteString.contains(";thumb") {
                url = URL(string: url.absoluteString.replacingOccurrences(of: ";thumb", with: ";image")) ?? url
            }

            flushTextBlock()
            pendingBreaks = 0
            let block = PostBlock.image(url)
            if !blocks.contains(block) { blocks.append(block) }
        }

        private mutating func appendTweetBlock(_ id: String) {
            flushTextBlock()
            pendingBreaks = 0
            let block = PostBlock.tweet(id)
            if !blocks.contains(block) { blocks.append(block) }
        }

        private mutating func appendVideoBlock(_ id: String) {
            flushTextBlock()
            pendingBreaks = 0
            let block = PostBlock.video(id)
            if !blocks.contains(block) { blocks.append(block) }
        }

        // MARK: Text

        private mutating func flushTextBlock() {
            guard !result.characters.isEmpty else { return }
            let trimmed = String(result.characters).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                result = AttributedString()
                return
            }
            blocks.append(.text(result))
            result = AttributedString()
        }

        private mutating func appendCodeBlock(_ raw: String) {
            flushTextBlock()
            pendingBreaks = 0
            var code = raw
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\u{00A0}", with: " ")
            code = code.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !code.isEmpty else { return }
            blocks.append(.code(code))
        }

        private mutating func appendText(_ raw: String) {
            guard !raw.isEmpty else { return }
            let text = style.code ? raw : collapseWhitespace(raw)
            append(text: text, style: style)
        }

        private mutating func append(childrenOf node: HTMLNode, container: AttributeContainer) {
            for child in node.children { append(child, container: container) }
        }

        private mutating func append(_ node: HTMLNode, container: AttributeContainer) {
            if node.isText {
                append(text: collapseWhitespace(node.text), container: container)
                return
            }
            switch node.tag {
            case "br":
                ensureBreak()
            case "img":
                appendInlineImage(node)
            default:
                for child in node.children { append(child, container: container) }
            }
        }

        private mutating func append(text: String, style: Style) {
            append(text: text, container: attributes(for: style))
        }

        private mutating func append(text raw: String, container: AttributeContainer) {
            guard !raw.isEmpty else { return }
            var text = raw
            if result.characters.isEmpty {
                while let first = text.first, first.isWhitespace { text.removeFirst() }
            }
            if result.characters.last == " " {
                while let first = text.first, first == " " { text.removeFirst() }
            }
            guard !text.isEmpty else { return }
            flushBreaks()
            var piece = AttributedString(text)
            piece.setAttributes(container)
            result += piece
        }

        // MARK: Breaks

        private mutating func ensureBreak() {
            pendingBreaks = min(pendingBreaks + 1, 2)
        }

        private mutating func flushBreaks() {
            guard pendingBreaks > 0 else { return }
            if !result.characters.isEmpty {
                var piece = AttributedString(String(repeating: "\n", count: pendingBreaks))
                piece.setAttributes(attributes(for: style))
                result += piece
            }
            pendingBreaks = 0
        }

        // MARK: Attributes

        private func attributes(for style: Style) -> AttributeContainer {
            var container = AttributeContainer()
            var size: CGFloat = style.isSmall ? 13 : 16
            if style.isHeader { size = 18 }
            if let override = style.size, override >= 10, override <= 34 {
                size = CGFloat(override)
            }

            var font = Font.system(size: size, design: style.code ? .monospaced : .default)
            if style.bold { font = font.weight(.semibold) }
            if style.italic { font = font.italic() }
            container.font = font

            if let color = style.color {
                container.foregroundColor = color
            } else {
                container.foregroundColor = style.quoteDepth > 0 ? Color.primary.opacity(0.76) : Color.primary
            }

            container[PostFontSizeAttribute.self] = Double(size)

            if let link = style.link {
                container.link = link
                container.underlineStyle = .single
            }

            var intent = InlinePresentationIntent()
            if style.bold { intent.insert(.stronglyEmphasized) }
            if style.italic { intent.insert(.emphasized) }
            if style.code { intent.insert(.code) }
            if !intent.isEmpty { container.inlinePresentationIntent = intent }

            return container
        }

        private func collapseWhitespace(_ string: String) -> String {
            let hadLeading = string.first?.isWhitespace ?? false
            let hadTrailing = string.last?.isWhitespace ?? false
            let core = string
                .replacingOccurrences(of: "\u{00A0}", with: " ")
                .split(whereSeparator: { $0.isWhitespace })
                .joined(separator: " ")
            if core.isEmpty { return hadLeading || hadTrailing ? " " : "" }
            return (hadLeading ? " " : "") + core + (hadTrailing ? " " : "")
        }

        // MARK: Finish

        mutating func finish() -> PostContent {
            flushTextBlock()

            var combined = AttributedString()
            for block in blocks {
                switch block {
                case .text(let text):
                    combined += text
                case .quote(_, let text):
                    if !combined.characters.isEmpty { combined += AttributedString("\n") }
                    combined += text
                    combined += AttributedString("\n")
                case .code(let code):
                    if !combined.characters.isEmpty { combined += AttributedString("\n") }
                    combined += AttributedString(code)
                case .image, .video, .tweet:
                    break
                }
            }

            var seen = Set<String>()
            let uniqueImages = images.filter { seen.insert($0.absoluteString).inserted }
            return PostContent(text: combined, blocks: blocks, images: uniqueImages)
        }
    }
}

extension AttributedString {
    /// Re-applies the user's post-text scale while keeping bold/italic/code.
    func scaledForPostText(_ scale: Double) -> AttributedString {
        guard scale != 1 else { return self }
        var copy = self
        for run in copy.runs {
            guard let size = run[PostRenderer.PostFontSizeAttribute.self] else { continue }
            var font = Font.system(size: size * scale)
            let intent = run.inlinePresentationIntent ?? []
            if intent.contains(.stronglyEmphasized) { font = font.weight(.semibold) }
            if intent.contains(.emphasized) { font = font.italic() }
            if intent.contains(.code) { font = .system(size: size * scale, design: .monospaced) }
            copy[run.range].font = font
        }
        return copy
    }
}
