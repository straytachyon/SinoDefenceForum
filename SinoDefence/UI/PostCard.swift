import SwiftUI
import WebKit

struct PostCard: View {
    @Environment(\.openURL) private var openURL
    @Environment(AppSettings.self) private var settings

    let post: ForumPost
    /// Used to hide subjects that only repeat the thread title ("Re: …").
    var topicTitle: String = ""
    /// Extra inset for the card's content (not its background) so text clears
    /// the notch/island when the strip itself runs edge to edge.
    var leadingInset: CGFloat = 0
    var trailingInset: CGFloat = 0
    var onQuote: ((ForumPost) -> Void)?
    var onModerate: ((ForumPost) -> Void)?
    var availableReactions: [ReactionOption] = []
    var onReact: ((ForumPost, Int) -> Void)?

    @State private var showReactionList = false

    private var galleryURLs: [URL] {
        var urls: [URL] = []
        for block in post.content.blocks {
            if case .image(let url) = block { urls.append(url) }
        }
        urls.append(contentsOf: post.content.images)
        var seen = Set<String>()
        return urls.filter { seen.insert($0.absoluteString).inserted }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                avatar

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(post.author)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        if post.isStaff {
                            Image(systemName: "shield.lefthalf.filled")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                    if !post.userTitle.isEmpty {
                        Text(post.userTitle)
                            .font(.caption2)
                            .foregroundStyle(AppTheme.secondaryText)
                            .lineLimit(1)
                    }
                    Text(post.dateText)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if let onQuote {
                    Button {
                        onQuote(post)
                    } label: {
                        Image(systemName: "quote.bubble")
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                            .frame(width: 30, height: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Quote post")
                }

                if let onModerate {
                    Menu {
                        Button("Delete Post", systemImage: "trash", role: .destructive) {
                            onModerate(post)
                        }
                        Button("Open Post in Browser", systemImage: "safari") {
                            openURL(post.postURL)
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                            .frame(width: 30, height: 28)
                    }
                    .accessibilityLabel("Moderator actions")
                }

                if let number = post.postNumber {
                    Text("#\(number)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }

            if !post.banners.isEmpty {
                HStack(spacing: 5) {
                    ForEach(post.banners, id: \.self) { banner in
                        Text(banner)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(AppTheme.accent.opacity(0.11)))
                    }
                }
            }

            if !post.content.blocks.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(post.content.blocks.enumerated()), id: \.offset) { _, block in
                        switch block {
                        case .text(let text):
                            Text(text.scaledForPostText(settings.postTextScale))
                                .textSelection(.enabled)
                                .tint(AppTheme.accent)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)

                        case .quote(let header, let text):
                            QuoteBlockView(header: header, text: text)

                        case .code(let code):
                            CodeBlockView(code: code)

                        case .image(let url):
                            InlinePostImage(url: url, gallery: galleryURLs)

                        case .tweet(let id):
                            TweetEmbedView(statusID: id)

                        case .video(let id):
                            VStack(alignment: .trailing, spacing: 4) {
                                YouTubeEmbedView(videoID: id)
                                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                                Button {
                                    if let watch = URL(string: "https://www.youtube.com/watch?v=\(id)") {
                                        openURL(watch)
                                    }
                                } label: {
                                    Label("Open on YouTube", systemImage: "arrow.up.right.square")
                                        .font(.caption2)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(AppTheme.secondaryText)
                            }
                        }
                    }
                }
            }

            if !post.content.images.isEmpty {
                PostImageGrid(urls: post.content.images, gallery: galleryURLs)
            }

            reactionBar
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, leadingInset)
        .padding(.trailing, trailingInset)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .sheet(isPresented: $showReactionList) {
            ReactionListSheet(post: post)
        }
    }

    @ViewBuilder
    private var reactionBar: some View {
        if post.canReact || !post.reactions.isEmpty || !post.reactionNames.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    ForEach(post.reactions) { reaction in
                        Button {
                            showReactionList = true
                        } label: {
                            ReactionIconView(reaction: reaction, size: 20)
                                .padding(2)
                                .background(
                                    Circle().fill(
                                        post.myReactionID == reaction.id
                                            ? AppTheme.accent.opacity(0.16)
                                            : Color.clear
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    if post.canReact, let onReact {
                        Menu {
                            ForEach(reactionChoices) { reaction in
                                Button {
                                    onReact(post, reaction.id)
                                } label: {
                                    HStack {
                                        Text("\(reaction.emoji)  \(reaction.name)")
                                        if post.myReactionID == reaction.id {
                                            Spacer()
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: post.myReactionID == nil ? "hand.thumbsup" : "hand.thumbsup.fill")
                                Text(post.myReactionID == nil ? "React" : "Change")
                            }
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(AppTheme.accent.opacity(0.10)))
                        }
                        .accessibilityLabel(post.myReactionID == nil ? "React to post" : "Change reaction")
                    }

                    Spacer(minLength: 0)

                    if post.reactionCount > 0 {
                        Text("\(post.reactionCount)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }

                if !post.reactionNames.isEmpty {
                    Button {
                        showReactionList = true
                    } label: {
                        Text(post.reactionNames)
                            .font(.caption2)
                            .foregroundStyle(AppTheme.secondaryText)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 3)
        }
    }

    private var reactionChoices: [ReactionOption] {
        availableReactions.isEmpty ? ReactionOption.defaults : availableReactions
    }

    private var avatar: some View {
        Group {
            if let url = post.avatarURL {
                RemoteAvatar(url: url)
            } else {
                initials
            }
        }
        .frame(width: 34, height: 34)
        .clipShape(Circle())
    }

    private var initials: some View {
        ZStack {
            Circle().fill(AppTheme.accent.opacity(0.14))
            Text(String(post.author.prefix(1)).uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.accent)
        }
    }
}

struct QuoteBlockView: View {
    let header: String
    let text: AttributedString
    @Environment(AppSettings.self) private var settings

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(AppTheme.accent.opacity(0.45))
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 4) {
                if !header.isEmpty {
                    Text(header)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(2)
                }
                Text(text.scaledForPostText(settings.postTextScale))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.tertiarySystemFill).opacity(0.75))
        )
    }
}

struct CodeBlockView: View {
    let code: String
    @Environment(AppSettings.self) private var settings

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(code)
                .font(.system(size: 13 * settings.postTextScale, design: .monospaced))
                .textSelection(.enabled)
                .fixedSize(horizontal: true, vertical: false)
                .padding(10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(.tertiarySystemFill))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

/// Inline image inside a post: keeps its position and shows the whole image
/// (no fixed-height cropping).
struct InlinePostImage: View {
    let url: URL
    var gallery: [URL] = []
    @State private var selection: GallerySelection?

    var body: some View {
        RemoteImage(url: url)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onTapGesture {
            let urls = gallery.isEmpty ? [url] : gallery
            selection = GallerySelection(index: urls.firstIndex(of: url) ?? 0)
        }
        .fullScreenCover(item: $selection) { selection in
            let urls = gallery.isEmpty ? [url] : gallery
            ImagePreview(urls: urls, startIndex: selection.index)
        }
    }
}

struct GallerySelection: Identifiable {
    let index: Int
    var id: Int { index }
}

struct PostImageGrid: View {
    let urls: [URL]
    var gallery: [URL] = []
    @State private var selection: GallerySelection?

    private var viewerURLs: [URL] { gallery.isEmpty ? urls : gallery }

    /// Adaptive columns squeeze a single picture into one narrow slot (left aligned).
    /// Use explicit columns instead: 1 image spans the card, 3 go side by side.
    private var columnCount: Int {
        switch urls.count {
        case 0, 1: return 1
        case 2: return 2
        case 3: return 3
        default: return 2
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: columnCount)
    }

    private var imageHeight: CGFloat {
        urls.count == 1 ? 230 : 140
    }

    var body: some View {
        Group {
            if urls.count == 1, let url = urls.first {
                // A lone attachment gets the full card width, sized by its own aspect.
                RemoteImage(url: url)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .onTapGesture {
                        selection = GallerySelection(index: viewerURLs.firstIndex(of: url) ?? 0)
                    }
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(urls, id: \.absoluteString) { url in
                        RemoteImage(url: url)
                            .frame(height: imageHeight)
                            .frame(maxWidth: .infinity)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .onTapGesture {
                                selection = GallerySelection(index: viewerURLs.firstIndex(of: url) ?? 0)
                            }
                    }
                }
            }
        }
        .padding(.top, 2)
        .fullScreenCover(item: $selection) { selection in
            ImagePreview(urls: viewerURLs, startIndex: selection.index)
        }
    }
}

struct ImagePreview: View {
    let urls: [URL]
    @State private var index: Int
    @State private var dragOffset: CGFloat = 0
    @State private var zoomed = false
    @Environment(\.dismiss) private var dismiss

    init(urls: [URL], startIndex: Int = 0) {
        self.urls = urls
        let clamped = min(max(startIndex, 0), max(urls.count - 1, 0))
        _index = State(initialValue: clamped)
    }

    var body: some View {
        ZStack {
            Color.black
                .opacity(1 - min(dragOffset / 700, 0.45))
                .ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(Array(urls.enumerated()), id: \.offset) { offset, url in
                    ZoomableImage(url: url, zoomed: $zoomed) { dismiss() }
                        .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: urls.count > 1 ? .always : .never))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .ignoresSafeArea()
            .offset(y: dragOffset)
            .simultaneousGesture(dismissDrag)

            VStack {
                HStack {
                    if urls.count > 1 {
                        Text("\(index + 1) / \(urls.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.45), in: Capsule())
                    }

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .white.opacity(0.18))
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                    .accessibilityLabel("Close image")
                }
                .padding(.horizontal, 10)
                .padding(.top, 4)

                Spacer()
            }
        }
    }

    /// Downward drag closes the viewer; horizontal drags still page.
    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard !zoomed,
                      abs(value.translation.height) > abs(value.translation.width) else { return }
                dragOffset = max(0, value.translation.height)
            }
            .onEnded { value in
                guard !zoomed else { return }
                let shouldDismiss = value.translation.height > 120
                    || value.predictedEndTranslation.height > 220
                if shouldDismiss {
                    dismiss()
                } else {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        dragOffset = 0
                    }
                }
            }
    }
}

/// One page of the photo viewer: pinch with two fingers to zoom (1×–5×).
private struct ZoomableImage: View {
    let url: URL
    @Binding var zoomed: Bool
    let onTap: () -> Void

    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image {
                NativeZoomableImage(image: image, onTap: onTap) { isZoomed in
                    zoomed = isZoomed
                }
            } else if failed {
                ContentUnavailableView(
                    "Image Unavailable",
                    systemImage: "photo.badge.exclamationmark",
                    description: Text("The picture could not be loaded.")
                )
                .foregroundStyle(.white)
            } else {
                ProgressView().tint(.white)
            }
        }
        .task(id: url) {
            guard image == nil else { return }
            image = await RemoteImageLoader.load(url)
            failed = image == nil
        }
    }
}

/// Native UIScrollView zooming: smooth panning, pinch zoom and momentum.
private struct NativeZoomableImage: UIViewRepresentable {
    let image: UIImage
    let onTap: () -> Void
    let onZoomChanged: (Bool) -> Void

    func makeUIView(context: Context) -> ZoomingScrollView {
        let scroll = ZoomingScrollView()
        scroll.delegate = context.coordinator
        context.coordinator.scrollView = scroll
        scroll.panGestureRecognizer.isEnabled = false
        scroll.setImage(image)

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped))
        scroll.imageView.addGestureRecognizer(tap)
        return scroll
    }

    func updateUIView(_ scroll: ZoomingScrollView, context: Context) {
        context.coordinator.onTap = onTap
        context.coordinator.onZoomChanged = onZoomChanged
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap, onZoomChanged: onZoomChanged)
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var onTap: () -> Void
        var onZoomChanged: (Bool) -> Void
        weak var scrollView: ZoomingScrollView?

        init(onTap: @escaping () -> Void, onZoomChanged: @escaping (Bool) -> Void) {
            self.onTap = onTap
            self.onZoomChanged = onZoomChanged
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            (scrollView as? ZoomingScrollView)?.imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            let isZoomed = scrollView.zoomScale > 1.01
            scrollView.panGestureRecognizer.isEnabled = isZoomed
            scrollView.setNeedsLayout()
            onZoomChanged(isZoomed)
        }

        @objc func tapped() {
            onTap()
        }
    }
}

private final class ZoomingScrollView: UIScrollView {
    let imageView = UIImageView()
    private var imageSize: CGSize = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        minimumZoomScale = 1
        maximumZoomScale = 5
        bouncesZoom = true
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        backgroundColor = .clear
        contentInsetAdjustmentBehavior = .never
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        addSubview(imageView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setImage(_ image: UIImage) {
        imageView.image = image
        imageSize = image.size
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard imageSize.width > 0, imageSize.height > 0,
              bounds.width > 0, bounds.height > 0 else { return }

        if zoomScale <= 1.001 {
            let ratio = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
            let size = CGSize(width: imageSize.width * ratio, height: imageSize.height * ratio)
            imageView.frame = CGRect(origin: .zero, size: size)
            contentSize = size
        }

        let x = max((bounds.width - contentSize.width) / 2, 0)
        let y = max((bounds.height - contentSize.height) / 2, 0)
        contentInset = UIEdgeInsets(top: y, left: x, bottom: y, right: x)
    }
}

/// Inline YouTube player. YouTube only exposes its player through the embed page,
/// so a small WKWebView is the reliable way to show and play it in-app.
struct YouTubeEmbedView: UIViewRepresentable {
    let videoID: String

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = .all

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.allowsBackForwardNavigationGestures = false

        // YouTube rejects a bare top-level embed ("Error 153"). Loading an iframe
        // document from the forum's origin gives it a valid embedding context.
        let origin = "https%3A%2F%2Fwww.sinodefenceforum.com"
        let html = """
        <!doctype html><html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        <style>html,body{margin:0;padding:0;background:#000;height:100%;overflow:hidden}
        iframe{position:absolute;inset:0;width:100%;height:100%;border:0}</style>
        </head><body>
        <iframe src="https://www.youtube.com/embed/\(videoID)?playsinline=1&rel=0&modestbranding=1&origin=\(origin)"
                allow="autoplay; encrypted-media; picture-in-picture; fullscreen"
                allowfullscreen></iframe>
        </body></html>
        """
        webView.loadHTMLString(html, baseURL: URL(string: "https://www.sinodefenceforum.com/"))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static func dismantleUIView(_ webView: WKWebView, coordinator: ()) {
        WebMedia.pause(in: webView)
    }
}

// MARK: - Images

/// Loads post pictures with the forum's cookies, then lays them out with their
/// real aspect ratio (AsyncImage collapsed to zero height inside cards).
///
/// Pictures on this forum come from three places: forum attachment files, forum
/// attachment *pages* (XenForo serves an HTML page with an `og:image`), and
/// external hosts — many of which still use `http://`. The loader handles all
/// three and deliberately does not send a forum Referer to external hosts that
/// may reject hot-linking.
enum RemoteImageLoader {
    private static let cache = NSCache<NSURL, UIImage>()

    private static let imageUserAgent =
        "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 " +
        "(KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 25
        configuration.timeoutIntervalForResource = 40
        configuration.httpShouldSetCookies = true
        configuration.httpCookieStorage = .shared
        // We keep decoded images in NSCache. Letting URLSession revalidate them
        // produces 304 responses, and the app cannot decode the empty 304 body.
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpAdditionalHeaders = [
            "User-Agent": AppConfig.userAgent,
            "Accept": "image/avif,image/webp,image/apng,image/*,*/*;q=0.8",
        ]
        return URLSession(configuration: configuration)
    }()

    static func load(_ url: URL) async -> UIImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        var image = await fetch(url, allowHTML: true, referer: isForumHost(url))
        if image == nil, !isForumHost(url) {
            // A few hosts reject requests without a forum Referer. Retry once
            // rather than showing a permanent placeholder.
            image = await fetch(url, allowHTML: true, referer: true)
        }
        guard let image else { return nil }
        cache.setObject(image, forKey: url as NSURL)
        return image
    }

    private static func fetch(_ url: URL, allowHTML: Bool, referer: Bool = false) async -> UIImage? {
        var request = URLRequest(url: url)
        request.setValue(imageUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(
            "image/avif,image/webp,image/apng,image/*,*/*;q=0.8",
            forHTTPHeaderField: "Accept"
        )
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if referer {
            request.setValue("https://www.sinodefenceforum.com/", forHTTPHeaderField: "Referer")
        }
        if isForumHost(url) {
            let cookies = HTTPCookieStorage.shared.cookies(for: url) ?? []
            let headers = HTTPCookie.requestHeaderFields(with: cookies)
            if let cookie = headers["Cookie"] {
                request.setValue(cookie, forHTTPHeaderField: "Cookie")
            }
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) || http.statusCode == 304 else { return nil }

            if let image = UIImage(data: data) { return image }
            if http.statusCode == 304 {
                // Some edge caches still revalidate despite the no-cache request.
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                var items = components?.queryItems ?? []
                items.append(URLQueryItem(name: "_sdf_image", value: String(Int(Date().timeIntervalSince1970))))
                components?.queryItems = items
                if let retryURL = components?.url, retryURL != url {
                    return await fetch(retryURL, allowHTML: false, referer: referer)
                }
            }

            guard allowHTML else { return nil }
            let contentType = http.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
            guard contentType.contains("html") || String(data: data.prefix(200), encoding: .utf8)?.contains("<") == true else {
                return nil
            }
            let html = String(data: data, encoding: .utf8) ?? ""
            guard let imageURL = imageURL(in: html, relativeTo: url) else { return nil }
            return await fetch(imageURL, allowHTML: false, referer: isForumHost(imageURL))
        } catch {
            return nil
        }
    }

    private static func isForumHost(_ url: URL) -> Bool {
        (url.host ?? "").lowercased().hasSuffix("sinodefenceforum.com")
    }

    static func isForumAttachment(_ url: URL) -> Bool {
        isForumHost(url) && url.path.lowercased().contains("/attachments/")
    }

    /// Reads the image XenForo references from an attachment page.
    private static func imageURL(in html: String, relativeTo base: URL) -> URL? {
        let document = HTMLParser.parse(html)
        let meta = document.all(where: { node in
            node.tag == "meta" && (node.attr("property") == "og:image" || node.attr("name") == "og:image")
        }).first
        if let source = meta?.attr("content"), let url = AppConfig.resolve(source, relativeTo: base) {
            return url
        }
        if let image = document.first(where: { $0.tag == "img" && $0.hasClass("bbImage") }),
           let source = image.attr("data-src") ?? image.attr("src"),
           let url = AppConfig.resolve(source, relativeTo: base) {
            return url
        }
        return nil
    }
}

struct RemoteImage<Failure: View, Loading: View>: View {
    let url: URL
    @ViewBuilder var failure: () -> Failure
    @ViewBuilder var loading: () -> Loading

    @Environment(\.forumSignedIn) private var signedIn
    @State private var image: UIImage?
    @State private var didFail = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(image.size, contentMode: .fit)
                    .frame(maxWidth: .infinity)            } else if didFail {
                failure()
            } else {
                loading()
            }
        }
        .task(id: "\(url.absoluteString)|\(signedIn)") { await load() }
    }

    private func load() async {
        didFail = false
        if let loaded = await RemoteImageLoader.load(url) {
            image = loaded
        } else {
            image = nil
            didFail = true
        }
    }
}

extension RemoteImage where Failure == AnyView, Loading == AnyView {
    init(url: URL) {
        self.init(
            url: url,
            failure: {
                AnyView(PostImageFailure(url: url))
            },
            loading: {
                AnyView(
                    ZStack {
                        Color(.tertiarySystemFill)
                        ProgressView()
                    }
                    .frame(height: 160)
                )
            }
        )
    }
}

struct PostImageFailure: View {
    let url: URL
    @Environment(\.forumSignedIn) private var signedIn
    @Environment(\.openURL) private var openURL

    private var needsSignIn: Bool {
        RemoteImageLoader.isForumAttachment(url) && !signedIn
    }

    var body: some View {
        Button {
            openURL(url)
        } label: {
            ZStack {
                Color(.tertiarySystemFill)
                VStack(spacing: 6) {
                    Image(systemName: needsSignIn ? "lock.fill" : "photo")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text(needsSignIn ? "Sign in to view picture" : "Picture unavailable")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if !needsSignIn {
                        Text("Tap to open")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(height: 160)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(needsSignIn ? "Sign in to view picture" : "Picture unavailable. Open in browser.")
    }
}

struct RemoteAvatar: View {
    let url: URL
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(AppTheme.accent.opacity(0.12))
                    Image(systemName: "person.fill")
                        .font(.caption)
                        .foregroundStyle(AppTheme.accent.opacity(0.65))
                }
            }
        }
        .task(id: url) {
            image = await RemoteImageLoader.load(url)
        }
    }
}
