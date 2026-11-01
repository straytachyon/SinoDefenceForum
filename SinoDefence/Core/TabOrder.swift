import Foundation

/// Persists the order of the board tabs. "New posts" is intentionally pinned first;
/// users reorder the boards behind it.
enum TabOrder {
    static let defaultsKey = "tabOrderBoardIDs"

    static func ordered(_ boards: [ForumBoard], saved: String) -> [ForumBoard] {
        guard !saved.isEmpty else { return boards }

        let ids = saved.split(separator: ",").compactMap { Int($0) }
        var lookup = Dictionary(uniqueKeysWithValues: boards.map { ($0.id, $0) })

        var result: [ForumBoard] = []
        for id in ids {
            if let board = lookup.removeValue(forKey: id) {
                result.append(board)
            }
        }
        // Boards added to the forum since the order was saved keep their forum order.
        for board in boards where lookup[board.id] != nil {
            result.append(board)
        }
        return result
    }

    static func token(for boards: [ForumBoard]) -> String {
        boards.map { String($0.id) }.joined(separator: ",")
    }
}
