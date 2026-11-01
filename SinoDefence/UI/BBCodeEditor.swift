import SwiftUI
import UIKit

/// Wraps a UITextView so toolbar buttons can wrap the current selection in BBCode
/// at the caret, something SwiftUI's TextEditor cannot do.
@MainActor
final class BBCodeEditorController {
    weak var textView: UITextView?

    func wrap(_ prefix: String, _ suffix: String, _ placeholder: String) {
        guard let textView else { return }
        let current = textView.text ?? ""
        let ns = current as NSString
        let selection = textView.selectedRange
        let selected = ns.substring(with: selection)
        let content = selected.isEmpty ? placeholder : selected
        let replacement = prefix + content + suffix

        apply(
            ns.replacingCharacters(in: selection, with: replacement),
            caret: selection.location + replacement.count
        )
    }

    func insert(_ text: String) {
        guard let textView else { return }
        let current = textView.text ?? ""
        let ns = current as NSString
        let selection = textView.selectedRange
        apply(
            ns.replacingCharacters(in: selection, with: text),
            caret: selection.location + text.count
        )
    }

    private func apply(_ text: String, caret: Int) {
        guard let textView else { return }
        textView.text = text
        textView.selectedRange = NSRange(location: caret, length: 0)
        // Programmatic edits don't call the delegate, so sync SwiftUI explicitly.
        textView.delegate?.textViewDidChange?(textView)
        textView.becomeFirstResponder()
    }
}

struct BBCodeEditor: UIViewRepresentable {
    @Binding var text: String
    let controller: BBCodeEditorController
    var placeholder: String = ""

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = .preferredFont(forTextStyle: .body)
        textView.textColor = .label
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        textView.alwaysBounceVertical = true
        textView.keyboardDismissMode = .interactive
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.autocorrectionType = .default
        textView.text = text
        controller.textView = textView
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.parent = self
        controller.textView = textView
        // Never stomp the text while the user is editing; the delegate keeps
        // SwiftUI's copy in sync. Only load external changes (e.g. quoted text).
        if !textView.isFirstResponder, textView.text != text {
            textView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: BBCodeEditor

        init(_ parent: BBCodeEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
    }
}
