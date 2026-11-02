import SwiftUI

private struct AlertDestination: Identifiable, Hashable {
    let id = UUID()
    let resolved: ResolvedThread

    static func == (lhs: AlertDestination, rhs: AlertDestination) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct XFAlertsView: View {
    @Environment(XFAlertsStore.self) private var alerts
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var link: WebLink?
    @State private var destination: AlertDestination?
    @State private var openingAlertID: String?

    var body: some View {
        NavigationStack {
            Group {
                if alerts.isLoading && alerts.items.isEmpty {
                    ProgressView("Loading notifications…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if alerts.items.isEmpty {
                    ContentUnavailableView {
                        Label("No Notifications", systemImage: "bell")
                    } description: {
                        VStack(spacing: 6) {
                            Text("Quotes, mentions and reactions will appear here.")
                            if let error = alerts.errorMessage {
                                Text(error)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                } else {
                    List(alerts.items) { alert in
                        Button {
                            Task { await open(alert) }
                        } label: {
                            HStack(alignment: .top, spacing: 9) {
                                Circle()
                                    .fill(alert.isUnread ? AppTheme.accent : Color.clear)
                                    .frame(width: 7, height: 7)
                                    .padding(.top, 6)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(alert.text)
                                        .font(.subheadline.weight(alert.isUnread ? .semibold : .regular))
                                        .foregroundStyle(.primary)
                                    if !alert.time.isEmpty {
                                        Text(alert.time)
                                            .font(.caption2)
                                            .foregroundStyle(AppTheme.secondaryText)
                                    }
                                }

                                Spacer(minLength: 4)

                                if openingAlertID == alert.id {
                                    ProgressView().controlSize(.small)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(alerts.unreadCount > 0 ? "Notifications (\(alerts.unreadCount))" : "Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $destination) { item in
                TopicDetailView(
                    topic: item.resolved.topic,
                    targetPostID: item.resolved.targetPostID
                )
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    if alerts.unreadCount > 0, alerts.markAllReadURL != nil {
                        Button("Mark All Read") {
                            Task { await alerts.markAllRead(session: session) }
                        }
                    }
                    Button("View All") {
                        link = WebLink(url: AppConfig.url("account/alerts/"))
                    }
                }
            }
            .refreshable { await alerts.refresh(session: session) }
            .task {
                if alerts.items.isEmpty { await alerts.refresh(session: session) }
            }
            .sheet(item: $link) { webLink in
                WebSheet(url: webLink.url)
            }
        }
    }

    private func open(_ alert: XFAlert) async {
        guard openingAlertID == nil else { return }
        openingAlertID = alert.id
        defer { openingAlertID = nil }

        if alert.isUnread {
            await alerts.markRead(alert, session: session)
        }
        guard let url = alert.url else { return }

        do {
            let resolved = try await XFClient.shared.resolveThread(from: url)
            destination = AlertDestination(resolved: resolved)
        } catch XFError.notLoggedIn {
            session.sessionExpired()
        } catch {
            alerts.errorMessage = error.localizedDescription
        }
    }
}
