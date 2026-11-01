import SwiftUI

/// Reorders the board tabs. Ordering is immediate and persisted, so the bottom tab
/// bar updates as soon as the sheet is dismissed (or live, on iPad's sidebar).
struct TabOrderEditor: View {
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @AppStorage(TabOrder.defaultsKey) private var storedOrder = ""

    @State private var boards: [ForumBoard] = []

    private var allBoards: [ForumBoard] {
        session.tabCategories.flatMap(\.boards)
    }

    var body: some View {
        List {
            Section {
                ForEach(boards) { board in
                    row(board)
                }
            } header: {
                Text("Board tabs")
            } footer: {
                Text("Use the arrows to move a board. “New posts” stays first; the first three boards appear as tabs and every board remains available in Forums. Changes are saved immediately.")
            }

            Section {
                Button("Reset to Forum Order", role: .destructive) {
                    withAnimation {
                        boards = allBoards
                    }
                }
                .disabled(boards == allBoards)
            }
        }
        .navigationTitle("Arrange Tabs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .onAppear {
            boards = TabOrder.ordered(allBoards, saved: storedOrder)
        }
        .onChange(of: boards) { _, newValue in
            storedOrder = TabOrder.token(for: newValue)
        }
    }

    private func row(_ board: ForumBoard) -> some View {
        HStack(spacing: 12) {
            Image(systemName: board.iconName)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 22)

            Text(board.name)
                .lineLimit(1)

            Spacer(minLength: 8)

            Button {
                move(board, by: -1)
            } label: {
                Image(systemName: "chevron.up")
                    .font(.body.weight(.semibold))
                    .frame(width: 32, height: 28)
            }
            .buttonStyle(.borderless)
            .disabled(index(of: board) == 0)
            .accessibilityLabel("Move \(board.name) up")

            Button {
                move(board, by: 1)
            } label: {
                Image(systemName: "chevron.down")
                    .font(.body.weight(.semibold))
                    .frame(width: 32, height: 28)
            }
            .buttonStyle(.borderless)
            .disabled(index(of: board) == boards.count - 1)
            .accessibilityLabel("Move \(board.name) down")
        }
    }

    private func index(of board: ForumBoard) -> Int {
        boards.firstIndex(of: board) ?? 0
    }

    private func move(_ board: ForumBoard, by offset: Int) {
        guard let current = boards.firstIndex(of: board) else { return }
        let target = current + offset
        guard boards.indices.contains(target) else { return }
        withAnimation(.easeInOut(duration: 0.18)) {
            boards.swapAt(current, target)
        }
    }
}
