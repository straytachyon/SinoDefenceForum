import SwiftUI
import WebKit

struct WebLink: Identifiable {
    let id = UUID()
    let url: URL
}

/// In-app browser. Cookies from the app's XenForo session are injected so forum pages that
/// require a login (for example "reply" or "profile") keep working.
struct WebSheet: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ForumWebView(url: url)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(url.host ?? "")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Link(destination: url) {
                            Image(systemName: "safari")
                        }
                        .accessibilityLabel("Open in Safari")
                    }
                }
        }
    }
}

struct ForumWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.refreshControl = UIRefreshControl()

        // Copy the app's forum cookies into the web view's cookie store.
        let cookies = HTTPCookieStorage.shared.cookies(for: AppConfig.baseURL) ?? []
        let store = WKWebsiteDataStore.default().httpCookieStore
        let group = DispatchGroup()
        for cookie in cookies {
            group.enter()
            store.setCookie(cookie) { group.leave() }
        }
        group.notify(queue: .main) {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        WebMedia.pause(in: webView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.scrollView.refreshControl?.endRefreshing()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            webView.scrollView.refreshControl?.endRefreshing()
        }
    }
}
