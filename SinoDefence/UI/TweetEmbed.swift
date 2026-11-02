import SwiftUI

/// Native X/Twitter card.
///
/// The Twitter widget iframe is unreliable on physical devices (content blockers,
/// third-party script restrictions and WebKit differences). This reads the public
/// syndication payload instead and renders the post with native SwiftUI, so text
/// and photos work consistently on iPhone and iPad.
struct TweetEmbedView: View {
    let statusID: String

    @State private var tweet: TweetInfo?
    @State private var isLoading = true
    @State private var failed = false

    private var tweetURL: URL? {
        URL(string: "https://x.com/i/status/\(statusID)")
    }

    var body: some View {
        Group {
            if let tweet {
                card(tweet)
            } else if isLoading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Loading post from X…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 72)
                .background(cardBackground)
            } else {
                fallbackCard
            }
        }
        .task(id: statusID) {
            await load()
        }
    }

    private func card(_ tweet: TweetInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 9) {
                AsyncImage(url: tweet.avatarURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        ZStack {
                            Circle().fill(Color.primary.opacity(0.08))
                            Text("X").font(.caption.bold()).foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 3) {
                        Text(tweet.authorName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        if tweet.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                    Text("@\(tweet.screenName)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Text("X")
                    .font(.headline.weight(.black))
                    .foregroundStyle(.primary)
                    .accessibilityLabel("X")
            }

            Text(tweet.text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            if !tweet.photos.isEmpty {
                TweetPhotoGrid(photos: tweet.photos)
            }

            HStack(spacing: 14) {
                if let date = tweet.date {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if tweet.likes > 0 {
                    Label("\(tweet.likes)", systemImage: "heart")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if tweet.replies > 0 {
                    Label("\(tweet.replies)", systemImage: "bubble.left")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if let tweetURL {
                    Link(destination: tweetURL) {
                        Label("Open on X", systemImage: "arrow.up.right.square")
                            .font(.caption2)
                    }
                }
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var fallbackCard: some View {
        HStack(spacing: 10) {
            Text("X")
                .font(.headline.weight(.black))
                .foregroundStyle(.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Post on X")
                    .font(.subheadline.weight(.semibold))
                Text("Tap to view this post in the browser.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if let tweetURL {
                Link(destination: tweetURL) {
                    Image(systemName: "arrow.up.right.square")
                }
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(.tertiarySystemFill).opacity(0.55))
    }

    private func load() async {
        if let cached = TweetInfo.cache.object(forKey: statusID as NSString)?.value {
            tweet = cached
            isLoading = false
            failed = false
            return
        }
        isLoading = true
        failed = false
        do {
            let loaded = try await TweetInfo.load(statusID)
            tweet = loaded
            TweetInfo.cache.setObject(TweetBox(loaded), forKey: statusID as NSString)
            isLoading = false
        } catch {
            tweet = nil
            isLoading = false
            failed = true
        }
    }
}

private struct TweetPhotoGrid: View {
    let photos: [TweetPhoto]

    private var columns: [GridItem] {
        if photos.count == 1 { return [GridItem(.flexible())] }
        return [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)]
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(photos.prefix(4)) { photo in
                AsyncImage(url: photo.url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        ZStack {
                            Color(.quaternarySystemFill)
                            ProgressView().controlSize(.small)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: photos.count == 1 ? 210 : 130)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }
}

// MARK: - Syndication model

final class TweetBox {
    let value: TweetInfo
    init(_ value: TweetInfo) { self.value = value }
}

struct TweetPhoto: Identifiable, Sendable {
    let id: String
    let url: URL
}

struct TweetInfo: Sendable {
    static let cache = NSCache<NSString, TweetBox>()

    var authorName: String
    var screenName: String
    var avatarURL: URL?
    var isVerified: Bool
    var text: String
    var date: Date?
    var photos: [TweetPhoto]
    var likes: Int
    var replies: Int

    static func load(_ statusID: String) async throws -> TweetInfo {
        guard let url = URL(string: "https://cdn.syndication.twimg.com/tweet-result?id=\(statusID)&lang=en&token=a") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 " +
            "(KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let payload = try JSONDecoder().decode(SyndicationPayload.self, from: data)
        guard let text = payload.text ?? payload.noteTweet?.noteTweetResults.result.text,
              let user = payload.user, !text.isEmpty else {
            throw URLError(.cannotParseResponse)
        }

        var photos: [TweetPhoto] = []
        var seen = Set<String>()
        for photo in payload.photos ?? [] {
            if let url = URL(string: photo.url), seen.insert(photo.url).inserted {
                photos.append(TweetPhoto(id: photo.url, url: url))
            }
        }
        for media in payload.mediaDetails ?? [] where media.type == "photo" {
            if let url = URL(string: media.mediaURLHTTPS), seen.insert(media.mediaURLHTTPS).inserted {
                photos.append(TweetPhoto(id: media.mediaURLHTTPS, url: url))
            }
        }

        let avatar: URL?
        if let rawAvatar = user.profileImageURLHTTPS {
            avatar = URL(string: rawAvatar.replacingOccurrences(of: "_normal", with: "_200x200"))
        } else {
            avatar = nil
        }

        return TweetInfo(
            authorName: user.name,
            screenName: user.screenName,
            avatarURL: avatar,
            isVerified: user.isBlueVerified || user.verified,
            text: text,
            date: TweetDate.parse(payload.createdAt),
            photos: photos,
            likes: payload.favoriteCount ?? 0,
            replies: payload.conversationCount ?? 0
        )
    }
}

private enum TweetDate {
    static func parse(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}

private struct SyndicationPayload: Decodable {
    struct User: Decodable {
        var name: String
        var screenName: String
        var profileImageURLHTTPS: String?
        var verified: Bool
        var isBlueVerified: Bool

        enum CodingKeys: String, CodingKey {
            case name
            case screenName = "screen_name"
            case profileImageURLHTTPS = "profile_image_url_https"
            case verified
            case isBlueVerified = "is_blue_verified"
        }
    }

    struct Photo: Decodable {
        var url: String
    }

    struct Media: Decodable {
        var type: String
        var mediaURLHTTPS: String

        enum CodingKeys: String, CodingKey {
            case type
            case mediaURLHTTPS = "media_url_https"
        }
    }

    struct NoteTweet: Decodable {
        struct Results: Decodable {
            struct Result: Decodable {
                var text: String
            }
            var result: Result
        }
        var noteTweetResults: Results

        enum CodingKeys: String, CodingKey {
            case noteTweetResults = "note_tweet_results"
        }
    }

    var text: String?
    var createdAt: String?
    var favoriteCount: Int?
    var conversationCount: Int?
    var user: User?
    var photos: [Photo]?
    var mediaDetails: [Media]?
    var noteTweet: NoteTweet?

    enum CodingKeys: String, CodingKey {
        case text
        case createdAt = "created_at"
        case favoriteCount = "favorite_count"
        case conversationCount = "conversation_count"
        case user
        case photos
        case mediaDetails
        case noteTweet
    }
}
