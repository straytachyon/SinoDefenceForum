import SwiftUI
import Observation

/// User-selectable appearance. `system` follows the device setting; the other two
/// force the app's colour scheme.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let defaultsKey = "appearanceMode"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var symbol: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}


private struct PostTextScaleKey: EnvironmentKey {
    static let defaultValue = 1.0
}

extension EnvironmentValues {
    var postTextScale: Double {
        get { self[PostTextScaleKey.self] }
        set { self[PostTextScaleKey.self] = newValue }
    }
}


@MainActor
@Observable
final class AppSettings {
    var postTextScale: Double {
        didSet {
            UserDefaults.standard.set(postTextScale, forKey: "postTextScale")
        }
    }

    init() {
        postTextScale = UserDefaults.standard.object(forKey: "postTextScale") as? Double ?? 1.0
    }
}


private struct ForumSignedInKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Lets image failure views distinguish a guest-only forum attachment from
    /// a genuinely dead external picture.
    var forumSignedIn: Bool {
        get { self[ForumSignedInKey.self] }
        set { self[ForumSignedInKey.self] = newValue }
    }
}
