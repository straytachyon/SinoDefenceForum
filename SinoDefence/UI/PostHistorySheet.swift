import SwiftUI

struct PostHistorySheet: View {
    let post: ForumPost
    let csrfToken: String

    @Environment(\.dismiss) private var dismiss
    @State private var entries: [PostHistoryEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading post history…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    let removed = errorMessage.localizedCaseInsensitiveContains("history has been removed")
                    ContentUnavailableView {
                        Label(removed ? "History Removed" : "History Unavailable", systemImage: "clock.arrow.circlepath")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        if !removed {
                            Button("Try Again") { Task { await load() } }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                } else {
                    List(entries) { entry in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(entry.dateText)
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                if !entry.editor.isEmpty {
                                    Text(entry.editor)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.secondaryText)
                                }
                            }
                            if !entry.reason.isEmpty {
                                Text("Reason: \(entry.reason)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if !entry.content.isEmpty {
                                Text(entry.content)
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.secondaryText)
                                    .lineLimit(5)
                            }
                        }
                        .padding(.vertical, 3)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Post History")
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
            entries = try await XFClient.shared.fetchPostHistory(
                postID: post.id,
                csrfToken: csrfToken
            )
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}
