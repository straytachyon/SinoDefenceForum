import Foundation

/// Small on-disk cache so the tab bar can be rebuilt instantly on the next launch,
/// before the board index has been fetched again.
enum CacheStore {
    private static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("SinoDefence", isDirectory: true)
    }

    private static var boardsFile: URL { directory.appendingPathComponent("boards.json") }

    static func save(_ categories: [ForumCategory]) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(categories)
            try data.write(to: boardsFile, options: .atomic)
        } catch {
            // Caching is best effort; a failure only costs a cold start.
        }
    }

    static func loadBoards() -> [ForumCategory]? {
        guard let data = try? Data(contentsOf: boardsFile),
              let categories = try? JSONDecoder().decode([ForumCategory].self, from: data),
              !categories.isEmpty else { return nil }
        return categories
    }

    static func clear() {
        try? FileManager.default.removeItem(at: boardsFile)
    }
}
