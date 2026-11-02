import SwiftUI

struct ReactionIconView: View {
    let reaction: ReactionOption
    var size: CGFloat = 19

    var body: some View {
        Group {
            if let url = reaction.iconURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                    } else {
                        Text(reaction.emoji)
                    }
                }
            } else {
                Text(reaction.emoji)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(reaction.name)
    }
}

struct ReactionListSheet: View {
    let post: ForumPost

    @Environment(\.dismiss) private var dismiss
    @State private var members: [ReactionMember] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading reactions…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    ContentUnavailableView {
                        Label("Couldn’t Load Reactions", systemImage: "hand.thumbsup")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Try Again") {
                            Task { await load() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if members.isEmpty {
                    ContentUnavailableView {
                        Label("No Reactions", systemImage: "hand.thumbsup")
                    } description: {
                        if !post.reactionNames.isEmpty {
                            Text(post.reactionNames)
                        } else {
                            Text("Nobody has reacted to this post yet.")
                        }
                    }
                } else {
                    List(members) { member in
                        HStack(spacing: 11) {
                            Group {
                                if let avatar = member.avatarURL {
                                    RemoteAvatar(url: avatar)
                                } else {
                                    ZStack {
                                        Circle().fill(AppTheme.accent.opacity(0.14))
                                        Text(String(member.name.prefix(1)).uppercased())
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(AppTheme.accent)
                                    }
                                }
                            }
                            .frame(width: 34, height: 34)
                            .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.name)
                                    .font(.subheadline.weight(.medium))
                                Text(member.reaction.name)
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.secondaryText)
                            }

                            Spacer(minLength: 4)
                            ReactionIconView(reaction: member.reaction, size: 22)
                            if !member.dateText.isEmpty {
                                Text(member.dateText)
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.secondaryText)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Reactions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            members = try await XFClient.shared.fetchReactions(postID: post.id)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}
