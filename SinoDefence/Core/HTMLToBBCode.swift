import Foundation

/// Converts XenForo's stored post HTML back into BBCode for the native editor.
/// It covers the formatting the app's composer can produce; unknown wrappers
/// fall back to their text content rather than dropping the post body.
enum HTMLToBBCode {
    static func convert(_ html: String) -> String {
        let document = HTMLParser.parse(html)
        let output = renderChildren(document)
        return output
            .replacingOccurrences(of: "\n\n\n", with: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func renderChildren(_ node: HTMLNode) -> String {
        node.children.map(render).joined()
    }

    private static func render(_ node: HTMLNode) -> String {
        if node.isText { return node.text }

        switch node.tag {
        case "br":
            return "\n"
        case "p":
            return renderChildren(node) + "\n\n"
        case "strong", "b":
            return "[b]\(renderChildren(node))[/b]"
        case "em", "i":
            return "[i]\(renderChildren(node))[/i]"
        case "u":
            return "[u]\(renderChildren(node))[/u]"
        case "s", "strike", "del":
            return "[s]\(renderChildren(node))[/s]"
        case "sup":
            return "[sup]\(renderChildren(node))[/sup]"
        case "sub":
            return "[sub]\(renderChildren(node))[/sub]"
        case "a":
            let href = node.attr("href") ?? ""
            let text = renderChildren(node)
            guard !href.isEmpty else { return text }
            return text == href || text.isEmpty ? "[url]\(href)[/url]" : "[url=\(href)]\(text)[/url]"
        case "img":
            guard let src = node.attr("data-src") ?? node.attr("src"), !src.isEmpty else { return "" }
            return "[img]\(src)[/img]"
        case "ul", "ol":
            let ordered = node.tag == "ol"
            let items = node.children.filter { $0.tag == "li" }
            let body = items.map { "[li]\(renderChildren($0))[/li]" }.joined(separator: "\n")
            return ordered ? "[list=1]\n\(body)\n[/list]\n\n" : "[list]\n\(body)\n[/list]\n\n"
        case "li":
            return "[li]\(renderChildren(node))[/li]"
        case "pre":
            let code = node.firstTag("code")?.rawText ?? node.rawText
            return "[code]\(code)[/code]\n\n"
        case "blockquote":
            let author = node.attr("data-quote") ?? ""
            let content = node.firstClass("bbCodeBlock-content") ?? node
            return "[quote=\"\(author)\"]\n\(renderChildren(content))\n[/quote]\n\n"
        case "iframe":
            if let src = node.attr("src"), let id = PostRenderer.youTubeID(from: URL(string: src) ?? URL(string: "https://youtube.com")!) {
                return "[youtube]\(id)[/youtube]\n\n"
            }
            return ""
        case "div":
            if node.hasClass("bbCodeBlock--spoiler") {
                let content = node.firstClass("bbCodeBlock-content") ?? node
                return "[spoiler]\n\(renderChildren(content))\n[/spoiler]\n\n"
            }
            if node.hasClass("bbCodeBlock--code") {
                return "[code]\(node.rawText)[/code]\n\n"
            }
            if node.hasClass("bbCodeBlock--quote") {
                let content = node.firstClass("bbCodeBlock-content") ?? node
                let author = node.firstClass("bbCodeBlock-title")?.textContent
                    .replacingOccurrences(of: " said:", with: "") ?? ""
                return "[quote=\"\(author)\"]\n\(renderChildren(content))\n[/quote]\n\n"
            }
            return renderChildren(node)
        case "table":
            return "[table]\n\(renderChildren(node))\n[/table]\n\n"
        case "tr":
            return "[tr]\n\(renderChildren(node))\n[/tr]\n"
        case "td", "th":
            return "[\(node.tag)]\(renderChildren(node))[/\(node.tag)]"
        default:
            return renderChildren(node)
        }
    }
}
