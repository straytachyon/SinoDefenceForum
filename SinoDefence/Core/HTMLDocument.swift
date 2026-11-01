import Foundation

/// A small, forgiving HTML DOM.
///
/// Forum pages are server-rendered and occasionally malformed (unclosed `<p>`/`<li>`),
/// so this parser auto-closes the usual suspects instead of failing. It is intentionally
/// dependency free and only implements what the forum client needs: element queries and
/// text extraction.
final class HTMLNode {
    let tag: String
    let attributes: [String: String]
    var children: [HTMLNode] = []
    weak var parent: HTMLNode?

    /// Only used when `tag == "#text"`.
    let text: String

    init(tag: String, attributes: [String: String] = [:], text: String = "") {
        self.tag = tag
        self.attributes = attributes
        self.text = text
    }

    var isText: Bool { tag == "#text" }

    static let voidTags: Set<String> = [
        "area", "base", "br", "col", "embed", "hr", "img", "input",
        "link", "meta", "param", "source", "track", "wbr",
    ]

    // MARK: Attributes

    func attr(_ name: String) -> String? { attributes[name] }
    var id: String? { attributes["id"] }
    var href: String? { attributes["href"] }
    var src: String? { attributes["src"] }

    var classList: [String] {
        guard let value = attributes["class"] else { return [] }
        return value.split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }

    func hasClass(_ name: String) -> Bool { classList.contains(name) }
    func hasAnyClass(_ names: [String]) -> Bool { names.contains(where: hasClass) }

    // MARK: Text

    var textContent: String {
        var output = ""
        func collect(_ node: HTMLNode) {
            if node.isText {
                output += node.text
                return
            }
            if node.tag == "br" { output += " "; return }
            if node.tag == "script" || node.tag == "style" { return }
            for child in node.children { collect(child) }
        }
        collect(self)
        return Self.normalizeWhitespace(output)
    }

    var rawText: String {
        var output = ""
        func collect(_ node: HTMLNode) {
            if node.isText { output += node.text; return }
            for child in node.children { collect(child) }
        }
        collect(self)
        return output
    }

    static func normalizeWhitespace(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    // MARK: Queries

    /// Pre-order traversal including this node.
    func walk(_ visit: (HTMLNode) -> Void) {
        visit(self)
        for child in children { child.walk(visit) }
    }

    var descendants: [HTMLNode] {
        var nodes: [HTMLNode] = []
        for child in children {
            child.walk { nodes.append($0) }
        }
        return nodes
    }

    func first(where predicate: (HTMLNode) -> Bool) -> HTMLNode? {
        if predicate(self) { return self }
        for child in children {
            if let match = child.first(where: predicate) { return match }
        }
        return nil
    }

    func all(where predicate: (HTMLNode) -> Bool) -> [HTMLNode] {
        var nodes: [HTMLNode] = []
        walk { if predicate($0) { nodes.append($0) } }
        return nodes
    }

    func firstTag(_ tag: String) -> HTMLNode? {
        first { $0.tag == tag }
    }

    func allTags(_ tag: String) -> [HTMLNode] {
        all { $0.tag == tag }
    }

    func firstClass(_ name: String) -> HTMLNode? {
        first { $0.hasClass(name) }
    }

    func allClasses(_ name: String) -> [HTMLNode] {
        all { $0.hasClass(name) }
    }

    func element(id: String) -> HTMLNode? {
        first { $0.attributes["id"] == id }
    }

    func ancestor(where predicate: (HTMLNode) -> Bool) -> HTMLNode? {
        var node = parent
        while let current = node {
            if predicate(current) { return current }
            node = current.parent
        }
        return nil
    }

    var previousSibling: HTMLNode? {
        guard let parent, let index = parent.children.firstIndex(where: { $0 === self }), index > 0 else { return nil }
        return parent.children[index - 1]
    }

    // MARK: Serialization

    var innerHTML: String {
        children.map { $0.serialized() }.joined()
    }

    func serialized() -> String {
        if isText { return Self.escape(text) }
        let attrs = attributes
            .sorted { $0.key < $1.key }
            .map { " \($0.key)=\"\(Self.escape($0.value))\"" }
            .joined()
        if Self.voidTags.contains(tag) { return "<\(tag)\(attrs)>" }
        return "<\(tag)\(attrs)>" + innerHTML + "</\(tag)>"
    }

    private static func escape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

// MARK: - Parser

enum HTMLParser {
    static func parse(_ html: String) -> HTMLNode {
        let chars = Array(html)
        let count = chars.count
        let root = HTMLNode(tag: "#root")
        var stack: [HTMLNode] = [root]
        var buffer = ""
        var index = 0

        func flushText() {
            guard !buffer.isEmpty else { return }
            let decoded = TextRepair.repair(Entities.decode(buffer))
            let node = HTMLNode(tag: "#text", text: decoded)
            node.parent = stack.last
            stack[stack.count - 1].children.append(node)
            buffer.removeAll(keepingCapacity: true)
        }

        while index < count {
            let char = chars[index]
            if char != "<" {
                buffer.append(char)
                index += 1
                continue
            }

            // Comments.
            if index + 3 < count, chars[index + 1] == "!", chars[index + 2] == "-", chars[index + 3] == "-" {
                flushText()
                var cursor = index + 4
                while cursor + 2 < count,
                      !(chars[cursor] == "-" && chars[cursor + 1] == "-" && chars[cursor + 2] == ">") {
                    cursor += 1
                }
                index = min(cursor + 3, count)
                continue
            }

            // Doctype / processing instruction.
            if index + 1 < count, chars[index + 1] == "!" || chars[index + 1] == "?" {
                flushText()
                var cursor = index + 2
                while cursor < count, chars[cursor] != ">" { cursor += 1 }
                index = min(cursor + 1, count)
                continue
            }

            // Closing tag.
            if index + 1 < count, chars[index + 1] == "/" {
                flushText()
                var cursor = index + 2
                var name = ""
                while cursor < count, chars[cursor].isLetter || chars[cursor].isNumber {
                    name.append(chars[cursor])
                    cursor += 1
                }
                while cursor < count, chars[cursor] != ">" { cursor += 1 }
                index = min(cursor + 1, count)

                let tag = name.lowercased()
                if let match = stack.lastIndex(where: { $0.tag == tag }), match > 0 {
                    stack.removeSubrange(match...)
                }
                continue
            }

            // Opening tag: find the terminating ">", ignoring any inside quotes.
            var cursor = index + 1
            var quote: Character?
            while cursor < count {
                let candidate = chars[cursor]
                if let activeQuote = quote {
                    if candidate == activeQuote { quote = nil }
                } else if candidate == "\"" || candidate == "'" {
                    quote = candidate
                } else if candidate == ">" {
                    break
                }
                cursor += 1
            }
            guard cursor < count else {
                buffer.append(char)
                index += 1
                continue
            }

            let source = String(chars[(index + 1)..<cursor])
            index = cursor + 1
            flushText()

            guard let parsed = parseTag(source) else { continue }
            while let top = stack.last, top.tag != "#root", shouldAutoClose(open: top.tag, for: parsed.name) {
                stack.removeLast()
            }

            let node = HTMLNode(tag: parsed.name, attributes: parsed.attributes)
            node.parent = stack.last
            stack.last?.children.append(node)

            if HTMLNode.voidTags.contains(parsed.name) || parsed.selfClosing { continue }

            // Raw-text elements: skip their contents entirely.
            if parsed.name == "script" || parsed.name == "style" {
                let closing = "</" + parsed.name
                var cursor2 = index
                while cursor2 < count {
                    if chars[cursor2] == "<",
                       String(chars[cursor2..<min(cursor2 + closing.count, count)]).lowercased() == closing {
                        break
                    }
                    cursor2 += 1
                }
                var end = cursor2
                while end < count, chars[end] != ">" { end += 1 }
                index = min(end + 1, count)
                continue
            }

            stack.append(node)
        }

        flushText()
        return root
    }

    // MARK: Private

    private static let blockTags: Set<String> = [
        "address", "article", "aside", "blockquote", "div", "dl", "fieldset", "footer",
        "form", "h1", "h2", "h3", "h4", "h5", "h6", "header", "hr", "li", "main",
        "nav", "ol", "option", "p", "pre", "section", "table", "td", "th", "tr", "ul",
    ]

    private static func shouldAutoClose(open: String, for newTag: String) -> Bool {
        if open == "p" { return newTag == "p" || blockTags.contains(newTag) }
        if open == "li" { return newTag == "li" }
        if open == "tr" { return newTag == "tr" }
        if open == "td" || open == "th" { return newTag == "td" || newTag == "th" || newTag == "tr" }
        if open == "option" { return newTag == "option" }
        if open == "dt" || open == "dd" { return newTag == "dt" || newTag == "dd" }
        return false
    }

    private static func parseTag(_ source: String) -> (name: String, attributes: [String: String], selfClosing: Bool)? {
        let chars = Array(source)
        var index = 0
        func skipWhitespace() {
            while index < chars.count, chars[index].isWhitespace { index += 1 }
        }

        skipWhitespace()
        var name = ""
        while index < chars.count, !chars[index].isWhitespace, chars[index] != "/" {
            name.append(chars[index])
            index += 1
        }
        guard !name.isEmpty else { return nil }

        var attributes: [String: String] = [:]
        var selfClosing = false

        while index < chars.count {
            skipWhitespace()
            guard index < chars.count else { break }
            if chars[index] == "/" { selfClosing = true; index += 1; continue }

            var key = ""
            while index < chars.count, !chars[index].isWhitespace, chars[index] != "=", chars[index] != "/" {
                key.append(chars[index])
                index += 1
            }
            skipWhitespace()

            var value = ""
            if index < chars.count, chars[index] == "=" {
                index += 1
                skipWhitespace()
                if index < chars.count, chars[index] == "\"" || chars[index] == "'" {
                    let quote = chars[index]
                    index += 1
                    while index < chars.count, chars[index] != quote {
                        value.append(chars[index])
                        index += 1
                    }
                    if index < chars.count { index += 1 }
                } else {
                    while index < chars.count, !chars[index].isWhitespace {
                        value.append(chars[index])
                        index += 1
                    }
                }
            }
            if !key.isEmpty {
                attributes[key.lowercased()] = Entities.decode(value)
            }
        }

        return (name.lowercased(), attributes, selfClosing)
    }
}

// MARK: - Entities

enum Entities {
    static func decode(_ string: String) -> String {
        guard string.contains("&") else { return string }
        var output = ""
        var index = string.startIndex

        while index < string.endIndex {
            let char = string[index]
            if char == "&",
               let semicolon = string[index...].firstIndex(of: ";"),
               string.distance(from: index, to: semicolon) <= 10 {
                let name = String(string[string.index(after: index)..<semicolon])
                if let replacement = replacement(for: name) {
                    output += replacement
                    index = string.index(after: semicolon)
                    continue
                }
            }
            output.append(char)
            index = string.index(after: index)
        }
        return output
    }

    private static func replacement(for name: String) -> String? {
        if name.hasPrefix("#") {
            let digits = String(name.dropFirst())
            let value: UInt32?
            if digits.hasPrefix("x") || digits.hasPrefix("X") {
                value = UInt32(digits.dropFirst(), radix: 16)
            } else {
                value = UInt32(digits, radix: 10)
            }
            if let value, let scalar = Unicode.Scalar(value) {
                return String(Character(scalar))
            }
            return nil
        }
        return named[name]
    }

    private static let named: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'",
        "nbsp": "\u{00A0}", "ensp": " ", "emsp": " ", "thinsp": " ",
        "hellip": "…", "mdash": "—", "ndash": "–", "minus": "−",
        "lsquo": "‘", "rsquo": "’", "ldquo": "“", "rdquo": "”",
        "laquo": "«", "raquo": "»", "bull": "•", "middot": "·",
        "copy": "©", "reg": "®", "trade": "™", "deg": "°",
        "times": "×", "divide": "÷", "plusmn": "±", "frac12": "½",
        "euro": "€", "pound": "£", "yen": "¥", "cent": "¢",
        "agrave": "à", "aacute": "á", "acirc": "â", "atilde": "ã", "auml": "ä", "aring": "å",
        "egrave": "è", "eacute": "é", "ecirc": "ê", "euml": "ë",
        "igrave": "ì", "iacute": "í", "icirc": "î", "iuml": "ï",
        "ograve": "ò", "oacute": "ó", "ocirc": "ô", "otilde": "õ", "ouml": "ö",
        "ugrave": "ù", "uacute": "ú", "ucirc": "û", "uuml": "ü",
        "ccedil": "ç", "ntilde": "ñ", "szlig": "ß", "yuml": "ÿ",
        "alpha": "α", "beta": "β", "gamma": "γ", "delta": "δ", "pi": "π", "sigma": "σ",
        "infin": "∞", "le": "≤", "ge": "≥", "ne": "≠", "asymp": "≈",
        "larr": "←", "rarr": "→", "uarr": "↑", "darr": "↓",
        "spades": "♠", "clubs": "♣", "hearts": "♥", "diams": "♦",
    ]
}


// MARK: - Legacy encoding repair

/// Some pre-migration posts contain UTF-8 that was decoded as Windows-1252 and stored
/// again ("PRCâ€™s"). The forum serves the page as UTF-8, so the damage is in the data;
/// undo the most common sequences when rendering text.
enum TextRepair {
    private static let replacements: [(String, String)] = [
        ("â€\u{009D}", "”"), ("â€™", "’"), ("â€˜", "‘"), ("â€œ", "“"),
        ("â€”", "—"), ("â€“", "–"), ("â€¦", "…"), ("â€¢", "•"),
        ("â„¢", "™"), ("Â»", "»"), ("Â«", "«"),
        ("Ã©", "é"), ("Ã¨", "è"), ("Ã ", "à"), ("Ã¼", "ü"),
        ("Ã¶", "ö"), ("Ã¤", "ä"), ("Ã±", "ñ"), ("Ã§", "ç"),
        ("Â\u{00A0}", " "), ("Â ", " "),
    ]

    static func repair(_ string: String) -> String {
        guard string.contains("â€") || string.contains("Ã") || string.contains("Â") else { return string }
        var output = string
        for (broken, fixed) in replacements {
            output = output.replacingOccurrences(of: broken, with: fixed)
        }
        return output
    }
}
