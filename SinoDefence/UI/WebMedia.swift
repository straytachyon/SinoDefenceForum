import WebKit

/// Stops media inside a web view when it is removed from the hierarchy, so a
/// video cannot keep playing (and holding the screen awake) after you leave.
enum WebMedia {
    static func pause(in webView: WKWebView) {
        let script = """
        document.querySelectorAll('video,audio').forEach(function (m) {
            try { m.pause(); m.removeAttribute('src'); m.load(); } catch (e) {}
        });
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
        webView.stopLoading()
    }
}
