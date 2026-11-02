import SwiftUI
import UIKit
import WebKit

/// Inline X/Twitter card. XenForo stores the status id in its oEmbed markup;
/// Twitter's widget script renders the actual post inside a small WKWebView.
struct TweetEmbedView: View {
    let statusID: String

    @Environment(\.colorScheme) private var colorScheme
    @State private var contentHeight: CGFloat = 320

    private var tweetURL: URL? {
        URL(string: "https://x.com/i/status/\(statusID)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TweetWebView(
                statusID: statusID,
                theme: colorScheme == .dark ? "dark" : "light",
                contentHeight: $contentHeight
            )
            .frame(height: min(max(contentHeight, 240), 760))
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.tertiarySystemFill).opacity(0.45))
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )

            if let tweetURL {
                HStack {
                    Spacer()
                    Link(destination: tweetURL) {
                        Label("Open on X", systemImage: "arrow.up.right.square")
                            .font(.caption2)
                    }
                }
            }
        }
    }
}

private struct TweetWebView: UIViewRepresentable {
    let statusID: String
    let theme: String
    @Binding var contentHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        configuration.userContentController.add(context.coordinator, name: "size")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.navigationDelegate = context.coordinator
        context.coordinator.load(statusID: statusID, theme: theme, in: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        if context.coordinator.theme != theme || context.coordinator.statusID != statusID {
            context.coordinator.load(statusID: statusID, theme: theme, in: webView)
        }
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "size")
        webView.stopLoading()
        webView.navigationDelegate = nil
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: TweetWebView
        var theme = ""
        var statusID = ""

        init(_ parent: TweetWebView) {
            self.parent = parent
        }

        func load(statusID: String, theme: String, in webView: WKWebView) {
            self.statusID = statusID
            self.theme = theme
            let html = """
            <!doctype html>
            <html>
            <head>
              <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
              <style>
                html, body { margin: 0; padding: 0; background: transparent; }
                body { color-scheme: \(theme); }
                .twitter-tweet { margin: 0 auto !important; }
              </style>
            </head>
            <body>
              <blockquote class="twitter-tweet" data-dnt="true" data-theme="\(theme)" data-conversation="none">
                <a href="https://twitter.com/x/status/\(statusID)">View post on X</a>
              </blockquote>
              <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>
              <script>
                function sendSize() {
                  const h = Math.max(document.body.scrollHeight, document.documentElement.scrollHeight);
                  window.webkit.messageHandlers.size.postMessage(h);
                }
                new ResizeObserver(sendSize).observe(document.body);
                window.addEventListener('load', () => setTimeout(sendSize, 700));
                setTimeout(sendSize, 1600);
                setTimeout(sendSize, 3000);
              </script>
            </body>
            </html>
            """
            webView.loadHTMLString(html, baseURL: URL(string: "https://www.sinodefenceforum.com/"))
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "size" else { return }
            let value: Double?
            if let number = message.body as? NSNumber {
                value = number.doubleValue
            } else if let string = message.body as? String {
                value = Double(string)
            } else {
                value = nil
            }
            guard let value, value > 80 else { return }
            DispatchQueue.main.async {
                self.parent.contentHeight = CGFloat(value)
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url,
               url.scheme == "https" || url.scheme == "http" {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
