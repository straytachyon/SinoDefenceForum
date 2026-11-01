import SwiftUI

/// New thread / reply composer with XenForo-style BBCode tools, a native
/// preview and submission through the forum's editor form.
struct ComposeView: View {
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss

    let mode: PostComposer.Mode
    var onPosted: (PostOutcome) -> Void

    @State private var model: PostComposer
    @State private var editor = BBCodeEditorController()
    @State private var showPreview = false

    @State private var showLinkDialog = false
    @State private var linkURL = ""
    @State private var linkText = ""

    @State private var showImageDialog = false
    @State private var imageURL = ""

    @State private var showYouTubeDialog = false
    @State private var youtubeURL = ""

    init(mode: PostComposer.Mode, onPosted: @escaping (PostOutcome) -> Void = { _ in }) {
        self.mode = mode
        self.onPosted = onPosted
        _model = State(initialValue: PostComposer(mode: mode))
    }

    var body: some View {
        NavigationStack {
            Group {
                if model.isLoading && model.form == nil {
                    ProgressView("Opening editor…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = model.errorMessage, model.form == nil {
                    ContentUnavailableView {
                        Label("Couldn’t Open Editor", systemImage: "square.and.pencil")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Try Again") {
                            Task { await model.load(session: session) }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    composeForm
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(model.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                formattingToolbar
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if model.isSubmitting {
                        ProgressView()
                    } else {
                        Button(model.isNewTopic ? "Post Thread" : "Post Reply") {
                            Task { await post() }
                        }
                        .disabled(!model.canSubmit)
                        .fontWeight(.semibold)
                    }
                }
            }
            .task { await model.load(session: session) }
            .onChange(of: session.phase) { _, phase in
                // Do not leave the editor floating over the login screen when
                // the forum session turns out to be invalid.
                if phase == .signedOut {
                    dismiss()
                }
            }
            .sheet(isPresented: $showPreview) {
                if let preview = model.preview {
                    PreviewSheet(subject: preview.subject, content: preview.content)
                }
            }
            .alert("Insert Link", isPresented: $showLinkDialog) {
                TextField("https://…", text: $linkURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Link text (optional)", text: $linkText)
                Button("Cancel", role: .cancel) {}
                Button("Insert") { insertLink() }
            } message: {
                Text("Enter the address to link to.")
            }
            .alert("Insert YouTube Video", isPresented: $showYouTubeDialog) {
                TextField("https://youtube.com/watch?v=…", text: $youtubeURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Cancel", role: .cancel) {}
                Button("Insert") { insertYouTube() }
            } message: {
                Text("Paste a YouTube link or an 11-character video ID.")
            }
            .alert("Insert Image", isPresented: $showImageDialog) {
                TextField("https://…", text: $imageURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Cancel", role: .cancel) {}
                Button("Insert") { insertImage() }
            } message: {
                Text("Paste the image URL. Forum attachments need to be uploaded in a browser.")
            }
        }
    }

    // MARK: - Form

    private var composeForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let board = model.boardName {
                    Label(board, systemImage: "bubble.left.and.bubble.right")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                if model.isNewTopic {
                    TextField("Subject", text: Binding(
                        get: { model.subject },
                        set: { model.subject = $0 }
                    ))
                    .textFieldStyle(.plain)
                    .font(.headline)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                    .accessibilityIdentifier("subjectField")
                }

                BBCodeEditor(
                    text: Binding(
                        get: { model.message },
                        set: { model.message = $0 }
                    ),
                    controller: editor,
                    placeholder: ""
                )
                .frame(minHeight: 230, maxHeight: 420)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .overlay(alignment: .topLeading) {
                    if model.message.isEmpty {
                        Text("Write your post…")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 20)
                            .padding(.leading, 15)
                            .allowsHitTesting(false)
                    }
                }

                HStack {
                    Text("\(model.message.count) characters")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.secondaryText)
                    Spacer()
                    Button {
                        Task {
                            await model.requestPreview(session: session)
                            if model.preview != nil { showPreview = true }
                        }
                    } label: {
                        Label("Preview", systemImage: "eye")
                            .font(.caption.weight(.medium))
                    }
                    .disabled(model.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isSubmitting)
                }

                if let error = model.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Formatting toolbar

    private var formattingToolbar: some View {
        FlowLayout(spacing: 4) {
                formatButton("bold", "Bold") { editor.wrap("[b]", "[/b]", "bold text") }
                formatButton("italic", "Italic") { editor.wrap("[i]", "[/i]", "italic text") }
                formatButton("underline", "Underline") { editor.wrap("[u]", "[/u]", "underlined text") }
                formatButton("strikethrough", "Strikethrough") { editor.wrap("[s]", "[/s]", "struck text") }

                formatButton("text.quote", "Quote") { editor.wrap("[quote]", "[/quote]", "Quote") }
                formatButton("chevron.left.forwardslash.chevron.right", "Code") { editor.wrap("[code]", "[/code]", "code") }
                formatButton("list.bullet", "Bullet list") {
                    editor.insert("[list]\n[li]item[/li]\n[/list]")
                }
                formatButton("list.number", "Numbered list") {
                    editor.insert("[list type=decimal]\n[li]item[/li]\n[/list]")
                }

                formatButton("link", "Insert link") { showLinkDialog = true }
                formatButton("photo", "Insert image") { showImageDialog = true }
                formatButton("play.rectangle", "Insert YouTube video") { showYouTubeDialog = true }

                Menu {
                    ForEach(["8pt", "10pt", "12pt", "14pt", "18pt", "24pt"], id: \.self) { size in
                        Button(size) { editor.wrap("[size=\(size)]", "[/size]", "text") }
                    }
                } label: {
                    Image(systemName: "textformat.size")
                        .frame(width: 30, height: 30)
                }
                .accessibilityLabel("Font size")

                Menu {
                    ForEach(["red", "blue", "green", "orange", "purple", "gray"], id: \.self) { color in
                        Button(color.capitalized) { editor.wrap("[color=\(color)]", "[/color]", "text") }
                    }
                } label: {
                    Image(systemName: "paintpalette")
                        .frame(width: 30, height: 30)
                }
                .accessibilityLabel("Font colour")

                Menu {
                    Button("Left") { editor.wrap("[left]", "[/left]", "text") }
                    Button("Center") { editor.wrap("[center]", "[/center]", "text") }
                    Button("Right") { editor.wrap("[right]", "[/right]", "text") }
                } label: {
                    Image(systemName: "text.alignleft")
                        .frame(width: 30, height: 30)
                }
                .accessibilityLabel("Alignment")

                formatButton("eye.slash", "Spoiler") { editor.wrap("[spoiler]", "[/spoiler]", "Spoiler") }
                formatButton("tablecells", "Table") {
                    editor.insert("[table]\n[tr]\n[td]cell[/td]\n[/tr]\n[/table]")
                }
                formatButton("textformat.superscript", "Superscript") { editor.wrap("[sup]", "[/sup]", "text") }
                formatButton("textformat.subscript", "Subscript") { editor.wrap("[sub]", "[/sub]", "text") }

                Menu {
                    ForEach(["Arial", "Times New Roman", "Courier New", "Verdana"], id: \.self) { face in
                        Button(face) { editor.wrap("[font=\(face)]", "[/font]", "text") }
                    }
                } label: {
                    Image(systemName: "textformat")
                        .frame(width: 30, height: 30)
                }
                .accessibilityLabel("Font face")

                Menu {
                    ForEach([":)", ":-)", ";)", ":D", ":P", ":(", ":o", "::)", ":laugh:"], id: \.self) { smiley in
                        Button(smiley) { editor.insert(smiley) }
                    }
                } label: {
                    Image(systemName: "face.smiling")
                        .frame(width: 30, height: 30)
                }
                .accessibilityLabel("Smileys")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private func formatButton(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 32, height: 30)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Actions

    private func insertLink() {
        let url = linkURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }
        let text = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
        editor.insert("[url=\(url)]\(text.isEmpty ? url : text)[/url]")
        linkURL = ""
        linkText = ""
    }

    private func insertYouTube() {
        let input = youtubeURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        var videoID: String?
        if let url = URL(string: input) {
            videoID = PostRenderer.youTubeID(from: url)
        }
        if videoID == nil, input.count == 11,
           input.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }) {
            videoID = input
        }
        guard let videoID else { return }

        editor.insert("[youtube]\(videoID)[/youtube]")
        youtubeURL = ""
    }

    private func insertImage() {
        let url = imageURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }
        editor.insert("[img]\(url)[/img]")
        imageURL = ""
    }

    private func post() async {
        guard let outcome = await model.submit(session: session) else { return }
        onPosted(outcome)
        dismiss()
    }
}

private struct PreviewSheet: View {
    let subject: String
    let content: PostContent
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if !subject.isEmpty {
                        Text(subject)
                            .font(.headline)
                    }
                    ForEach(Array(content.blocks.enumerated()), id: \.offset) { _, block in
                        switch block {
                        case .text(let text):
                            Text(text.scaledForPostText(settings.postTextScale))
                                .textSelection(.enabled)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        case .quote(let header, let text):
                            QuoteBlockView(header: header, text: text)
                        case .code(let code):
                            CodeBlockView(code: code)
                        case .image(let url):
                            InlinePostImage(url: url)
                        case .video(let id):
                            YouTubeEmbedView(videoID: id)
                                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }

                    if !content.images.isEmpty {
                        PostImageGrid(urls: content.images)
                    }
                }
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
