import SwiftUI

struct PostHistorySheet: View {
    let post: ForumPost
    let csrfToken: String

    @Environment(\.dismiss) private var dismiss
    @State private var entries: [PostHistoryEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedEntry: PostHistoryEntry?

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
                        Button {
                            if entry.revisionURL != nil { selectedEntry = entry }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(entry.dateText)
                                        .font(.subheadline.weight(.medium))
                                    if !entry.editor.isEmpty {
                                        Text("Edited by \(entry.editor)")
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.secondaryText)
                                    }
                                    if !entry.reason.isEmpty {
                                        Text("Reason: \(entry.reason)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if entry.revisionURL != nil {
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(entry.revisionURL == nil)
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
            .sheet(item: $selectedEntry) { entry in
                RevisionContentSheet(entry: entry, csrfToken: csrfToken)
            }
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

private struct RevisionContentSheet: View {
    let entry: PostHistoryEntry
    let csrfToken: String

    @Environment(\.dismiss) private var dismiss
    @State private var content: PostContent?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading version…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage {
                    ContentUnavailableView {
                        Label("Version Unavailable", systemImage: "doc.text")
                    } description: {
                        Text(errorMessage)
                    }
                } else if let content {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            if !entry.editor.isEmpty {
                                Text("Edited by \(entry.editor) · \(entry.dateText)")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                            PostBlocksView(content: content)
                        }
                        .padding(16)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Version")
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
        guard let url = entry.revisionURL else { return }
        isLoading = true
        errorMessage = nil
        do {
            content = try await XFClient.shared.fetchHistoryRevision(url: url, csrfToken: csrfToken)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}
