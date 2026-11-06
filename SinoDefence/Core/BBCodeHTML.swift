import Foundation

/// Converts the BBCode typed in the composer into the subset of HTML that
/// XenForo's editor submits. The server converts it to its canonical storage
/// format, so formatting, quotes, links and images survive round trips.
enum BBCodeHTML {
    static func convert(_ input: String) -> String {
        var html = render(input[...], until: nil).0
        html = html.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !html.isEmpty else { return "" }

        // XenForo's 2.3 rich-text editor emits block HTML. A bare text run or
        // inline tag is rejected by some message parsers and can create a post
        // with no body, so make sure every message has a paragraph wrapper.
        let hasBlock = ["<p", "<div", "<blockquote", "<ul", "<ol", "<pre", "<table", "<hr"]
            .contains { html.localizedCaseInsensitiveContains($0) }
        if !hasBlock {
            html = "<p>\(html)</p>"
        }
        return html
    }

    // MARK: - Recursive renderer

    private static func render(_ text: Substring, until closing: String?) -> (String, Substring.Index) {
        var output = ""
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]
            guard character == "[", let close = text[index...].firstIndex(of: "]") else {
                output += escape(String(character))
                index = text.index(after: index)
                continue
            }

            let body = String(text[text.index(after: index)..<close])
            let afterTag = text.index(after: close)

            if body.hasPrefix("/") {
                let name = body.dropFirst().lowercased()
                if name == closing {
                    return (output, afterTag)
                }
                output += escape(String(text[index...close]))
                index = afterTag
                continue
            }

            guard let tag = parseTag(body) else {
                output += escape(String(text[index...close]))
                index = afterTag
                continue
            }

            switch tag.name {
            case "b", "i", "u", "s", "sup", "sub", "center", "left", "right",
                 "color", "size", "font", "spoiler", "quote", "list", "li",
                 "url", "table", "tr", "td", "th":
                let (inner, next) = render(text[afterTag...], until: tag.name)
                output += element(tag: tag, inner: inner)
                index = next

            case "code", "icode":
                let (raw, next) = rawContent(text[afterTag...], until: tag.name)
                if tag.name == "icode" {
                    output += "<code class=\"bbCodeInline\">\(escape(raw))</code>"
                } else {
                    output += "<pre class=\"bbCodeBlock bbCodeBlock--code\"><code class=\"bbCodeCode\">\(escape(raw))</code></pre>"
                }
                index = next

            case "img":
                let (raw, next) = rawContent(text[afterTag...], until: tag.name)
                let url = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if !url.isEmpty {
                    output += "<img src=\"\(escapeAttribute(url))\" class=\"bbImage\" alt=\"\">"
                }
                index = next

            case "youtube", "media":
                let (raw, next) = rawContent(text[afterTag...], until: tag.name)
                let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if let id = videoID(value) {
                    output += "<div class=\"bbCodeBlock bbCodeBlock--embed\"><iframe src=\"https://www.youtube.com/embed/\(escapeAttribute(id))\" allowfullscreen></iframe></div>"
                } else if !value.isEmpty {
                    output += "<a href=\"\(escapeAttribute(value))\">\(escape(value))</a>"
                }
                index = next

            case "br":
                output += "<br>"
                index = afterTag

            case "hr":
                output += "<hr>"
                index = afterTag

            default:
                output += escape(String(text[index...close]))
                index = afterTag
            }
        }

        return (output, index)
    }

    private static func element(tag: Tag, inner: String) -> String {
        switch tag.name {
        case "b": return "<strong>\(inner)</strong>"
        case "i": return "<em>\(inner)</em>"
        case "u": return "<u>\(inner)</u>"
        case "s": return "<s>\(inner)</s>"
        case "sup": return "<sup>\(inner)</sup>"
        case "sub": return "<sub>\(inner)</sub>"
        case "left": return "<div style=\"text-align:left\">\(inner)</div>"
        case "center": return "<div style=\"text-align:center\">\(inner)</div>"
        case "right": return "<div style=\"text-align:right\">\(inner)</div>"
        case "color":
            return "<span style=\"color:\(safeCSS(tag.value ?? "inherit"))\">\(inner)</span>"
        case "size":
            return "<span style=\"font-size:\(fontSize(tag.value))px\">\(inner)</span>"
        case "font":
            return "<span style=\"font-family:\(safeCSS(tag.value ?? "inherit"))\">\(inner)</span>"
        case "spoiler":
            return "<div class=\"bbCodeBlock bbCodeBlock--spoiler\"><div class=\"bbCodeBlock-title\">Spoiler</div><div class=\"bbCodeBlock-content\">\(inner)</div></div>"
        case "quote":
            let author = tag.value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let title = author.isEmpty ? "Quote" : "\(escape(author)) said:"
            return "<blockquote data-attributes=\"\" data-quote=\"\(escapeAttribute(author))\" class=\"bbCodeBlock bbCodeBlock--quote\"><div class=\"bbCodeBlock-title\">\(title)</div><div class=\"bbCodeBlock-content\">\(inner)</div></blockquote>"
        case "list":
            let ordered = tag.value?.lowercased() == "1" || tag.value?.lowercased() == "decimal"
            return ordered ? "<ol>\(inner)</ol>" : "<ul>\(inner)</ul>"
        case "li":
            return "<li>\(inner)</li>"
        case "url":
            let value = tag.value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if value.isEmpty {
                let text = stripTags(inner)
                return "<a href=\"\(escapeAttribute(text))\">\(inner)</a>"
            }
            return "<a href=\"\(escapeAttribute(value))\">\(inner)</a>"
        case "table": return "<table>\(inner)</table>"
        case "tr": return "<tr>\(inner)</tr>"
        case "td": return "<td>\(inner)</td>"
        case "th": return "<th>\(inner)</th>"
        default: return inner
        }
    }

    // MARK: - Raw blocks

    private static func rawContent(_ text: Substring, until name: String) -> (String, Substring.Index) {
        let marker = "[/\(name)]"
        if let range = text.range(of: marker, options: .caseInsensitive) {
            return (String(text[..<range.lowerBound]), range.upperBound)
        }
        return (String(text), text.endIndex)
    }

    private struct Tag {
        var name: String
        var value: String?
    }

    private static func parseTag(_ body: String) -> Tag? {
        guard !body.isEmpty else { return nil }
        let lower = body.lowercased()
        let namePart: String
        var value: String?
        if let equals = lower.firstIndex(of: "=") {
            namePart = String(lower[..<equals]).trimmingCharacters(in: .whitespaces)
            value = String(body[body.index(after: equals)...])
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
        } else {
            namePart = lower.trimmingCharacters(in: .whitespaces)
        }
        let allowed = Set([
            "b", "i", "u", "s", "sup", "sub", "center", "left", "right",
            "color", "size", "font", "spoiler", "quote", "list", "li",
            "url", "img", "code", "icode", "youtube", "media", "br", "hr",
            "table", "tr", "td", "th",
        ])
        guard allowed.contains(namePart) else { return nil }
        return Tag(name: namePart, value: value)
    }

    // MARK: - Escaping

    private static func escape(_ string: String) -> String {
        var output = ""
        output.reserveCapacity(string.count)
        for character in string {
            switch character {
            case "&": output += "&amp;"
            case "<": output += "&lt;"
            case ">": output += "&gt;"
            case "\n": output += "<br>"
            case "\r": break
            default: output.append(character)
            }
        }
        return output
    }

    private static func escapeAttribute(_ string: String) -> String {
        escape(string)
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<br>", with: " ")
    }

    private static func safeCSS(_ value: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#,.%- _")
        return value.unicodeScalars.filter { allowed.contains($0) }.map(String.init).joined()
    }

    private static func fontSize(_ raw: String?) -> String {
        guard let raw, let value = Int(raw.trimmingCharacters(in: .whitespaces)) else { return "16" }
        switch value {
        case 1: return "10"
        case 2: return "12"
        case 3: return "16"
        case 4: return "18"
        case 5: return "22"
        case 6: return "26"
        case 7: return "32"
        default: return String(min(max(value, 8), 40))
        }
    }

    private static func stripTags(_ html: String) -> String {
        html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
    }

    private static func videoID(_ value: String) -> String? {
        if let url = URL(string: value), let id = PostRenderer.youTubeID(from: url) { return id }
        if value.count == 11, value.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }) {
            return value
        }
        return nil
    }
}
