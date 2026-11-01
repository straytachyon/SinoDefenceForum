import SwiftUI

/// Keeps the brand red visible in both enabled and disabled states. The system
/// `.borderedProminent` style greys the disabled fill so aggressively that the
/// label becomes unreadable on a dark background.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PrimaryButtonBody(configuration: configuration)
    }

    private struct PrimaryButtonBody: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.vertical, 15)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppTheme.accent.opacity(isEnabled ? 1 : 0.5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(.white.opacity(isEnabled ? 0.14 : 0.22), lineWidth: 1)
                )
                .opacity(configuration.isPressed ? 0.85 : 1)
                .scaleEffect(configuration.isPressed ? 0.99 : 1)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        }
    }
}

struct LoginView: View {
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    var showsGuestOption = true
    var onClose: (() -> Void)?
    var onSignedIn: (() -> Void)?

    @Environment(Session.self) private var session

    @State private var username = ""
    @State private var password = ""
    @State private var remember = true
    @State private var revealPassword = false
    @State private var isSigningIn = false
    @State private var isEnteringGuest = false
    @State private var errorMessage: String?
    @State private var showWebsite = false
    @FocusState private var focus: Field?

    private enum Field {
        case username, password
    }

    private var canSubmit: Bool {
        !username.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }

    var body: some View {
        ZStack {
            AppTheme.heroGradient.ignoresSafeArea()

            if let onClose {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white.opacity(0.9))
                                .frame(width: 36, height: 36)
                                .background(.black.opacity(0.22), in: Circle())
                        }
                        .accessibilityLabel("Close")
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            ScrollView {
                VStack(spacing: 24) {
                    header
                    credentials
                    rememberToggle

                    if let message = errorMessage ?? session.notice {
                        notice(message)
                    }

                    footer
                }
                .frame(maxWidth: 440)
                .padding(.horizontal, 22)
                .padding(.top, verticalSizeClass == .compact ? 12 : 36)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) {
                signInButton

                if showsGuestOption {
                    Button {
                        enterAsGuest()
                    } label: {
                        HStack(spacing: 6) {
                            if isEnteringGuest { ProgressView().tint(.white.opacity(0.8)) }
                            Text("Browse as a Guest")
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundStyle(.white.opacity(0.82))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .disabled(isSigningIn || isEnteringGuest)
                }
            }
            .frame(maxWidth: 440)
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity)
            .background(AppTheme.heroGradient)
        }
        .onAppear {
            if username.isEmpty { username = session.savedUsername ?? "" }
        }
        .sheet(isPresented: $showWebsite) {
            WebSheet(url: AppConfig.forumDisplayURL)
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(spacing: verticalSizeClass == .compact ? 8 : 16) {
            AppMark(size: verticalSizeClass == .compact ? 54 : 92)

            VStack(spacing: 6) {
                Text(AppConfig.forumName)
                    .font(verticalSizeClass == .compact ? .title2.weight(.bold) : .title.weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                if verticalSizeClass != .compact {
                    Text("Sign in to post, or browse New posts, boards and threads without an account.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.66))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
            }
        }
        .padding(.bottom, 4)
    }

    private var credentials: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "person.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

                TextField("Username", text: $username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .username)
                    .submitLabel(.next)
                    .onSubmit { focus = .password }
            }
            .padding(15)

            Divider().padding(.leading, 47)

            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

                Group {
                    if revealPassword {
                        TextField("Password", text: $password)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else {
                        SecureField("Password", text: $password)
                    }
                }
                .textContentType(.password)
                .focused($focus, equals: .password)
                .submitLabel(.go)
                .onSubmit(submit)

                if !password.isEmpty {
                    Button {
                        revealPassword.toggle()
                    } label: {
                        Image(systemName: revealPassword ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(revealPassword ? "Hide password" : "Show password")

                    Button {
                        password = ""
                        focus = .password
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear password")
                }
            }
            .padding(15)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
        .disabled(isSigningIn)
    }

    private var rememberToggle: some View {
        Toggle(isOn: $remember) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Stay signed in")
                    .font(.subheadline.weight(.medium))
                Text("Keeps your password in the iOS Keychain so expired XenForo sessions renew automatically.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .tint(AppTheme.accent)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground).opacity(0.92))
        )
    }

    private var signInButton: some View {
        Button(action: submit) {
            HStack(spacing: 8) {
                if isSigningIn {
                    ProgressView().tint(.white)
                }
                Text(isSigningIn ? "Signing In…" : "Sign In")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(!canSubmit || isSigningIn)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Text("Unofficial client for \(AppConfig.forumHost). Credentials are only sent to the forum itself and never leave your device except as a normal login request. Guest browsing uses the forum's public pages.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.66))
                .multilineTextAlignment(.center)

            Button {
                showWebsite = true
            } label: {
                Label("Open forum website", systemImage: "safari")
                    .font(.caption.weight(.medium))
            }
            .tint(.white.opacity(0.85))
        }
        .padding(.top, 4)
    }

    private func notice(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.black.opacity(0.28))
        )
    }

    // MARK: - Actions

    private func enterAsGuest() {
        guard !isEnteringGuest else { return }
        focus = nil
        isEnteringGuest = true
        Task {
            await session.enterGuestMode()
            isEnteringGuest = false
        }
    }

    private func submit() {
        guard canSubmit, !isSigningIn else { return }
        focus = nil
        errorMessage = nil
        isSigningIn = true

        Task {
            do {
                try await session.signIn(
                    username: username.trimmingCharacters(in: .whitespaces),
                    password: password,
                    remember: remember
                )
                onSignedIn?()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSigningIn = false
        }
    }
}
