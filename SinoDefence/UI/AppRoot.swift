import SwiftUI

enum AppTheme {
    /// Sino Defence Forum's masthead blue, sampled from the site's theme colour.
    static let accent = Color(red: 0.06, green: 0.34, blue: 0.54)
    static let navy = Color(red: 0.07, green: 0.20, blue: 0.31)
    static let red = Color(red: 0.74, green: 0.12, blue: 0.11)

    /// Metadata grey that still clears 4.5:1 on grouped backgrounds.
    static var secondaryText: Color { Color.primary.opacity(0.58) }

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.04, green: 0.14, blue: 0.22), Color(red: 0.06, green: 0.28, blue: 0.43)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var markGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.09, green: 0.44, blue: 0.66), Color(red: 0.04, green: 0.22, blue: 0.36)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

struct AppMark: View {
    var size: CGFloat = 72

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(AppTheme.markGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: size * 0.14, y: size * 0.06)

            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(.white)

            Image(systemName: "star.fill")
                .font(.system(size: size * 0.16, weight: .bold))
                .foregroundStyle(Color(red: 0.98, green: 0.82, blue: 0.36))
                .offset(y: -size * 0.005)
        }
        .frame(width: size, height: size)
    }
}

struct RootView: View {
    @Environment(Session.self) private var session

    var body: some View {
        ZStack {
            switch session.phase {
            case .restoring:
                LaunchView().transition(.opacity)
            case .signedOut:
                LoginView().transition(.opacity)
            case .guest, .signedIn:
                MainTabs().transition(.opacity)
            }
        }
        .environment(\.forumSignedIn, session.isSignedIn)
        .task { await session.bootstrap() }
        .animation(.easeInOut(duration: 0.22), value: session.phase)
    }
}

struct LaunchView: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            AppTheme.heroGradient.ignoresSafeArea()
            VStack(spacing: 18) {
                AppMark(size: 88)
                VStack(spacing: 4) {
                    Text(AppConfig.forumName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(AppConfig.forumSubtitle)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.6))
                }
                ProgressView()
                    .tint(.white.opacity(0.8))
                    .padding(.top, 8)
                    .opacity(pulse ? 1 : 0.45)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
