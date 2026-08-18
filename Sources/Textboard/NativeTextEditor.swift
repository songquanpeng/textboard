import AppKit
import SwiftUI

private final class TabTextView: NSTextView {
  private let minimumHorizontalInset: CGFloat = 42
  private let preferredLineWidth: CGFloat = 720

  override func keyDown(with event: NSEvent) {
    if event.keyCode == 48, event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
      insertText("\t", replacementRange: selectedRange())
      return
    }
    super.keyDown(with: event)
  }

  override func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)
    let horizontalInset = max(minimumHorizontalInset, (newSize.width - preferredLineWidth) / 2)
    textContainerInset = NSSize(width: horizontalInset, height: 38)
  }
}

struct NativeTextEditor: NSViewRepresentable {
  @Binding var text: String

  func makeCoordinator() -> Coordinator {
    Coordinator(text: $text)
  }

  func makeNSView(context: Context) -> NSScrollView {
    let scrollView = NSScrollView()
    scrollView.hasVerticalScroller = true
    scrollView.autohidesScrollers = true
    scrollView.drawsBackground = true
    scrollView.backgroundColor = .textBackgroundColor
    scrollView.borderType = .noBorder

    let textView = TabTextView()
    textView.delegate = context.coordinator
    textView.isRichText = false
    textView.allowsUndo = true
    textView.isAutomaticQuoteSubstitutionEnabled = false
    textView.isAutomaticDashSubstitutionEnabled = false
    textView.isAutomaticTextReplacementEnabled = false
    textView.isContinuousSpellCheckingEnabled = false
    textView.drawsBackground = true
    textView.backgroundColor = .textBackgroundColor
    textView.textColor = .textColor
    textView.font = .monospacedSystemFont(ofSize: 14.5, weight: .regular)
    textView.textContainerInset = NSSize(width: 42, height: 38)
    textView.textContainer?.widthTracksTextView = true
    textView.textContainer?.lineFragmentPadding = 0
    textView.isVerticallyResizable = true
    textView.isHorizontallyResizable = false
    textView.autoresizingMask = [.width]
    textView.string = text
    textView.setAccessibilityLabel("文稿内容")

    let paragraph = NSMutableParagraphStyle()
    paragraph.lineSpacing = 5
    textView.defaultParagraphStyle = paragraph
    textView.typingAttributes[.paragraphStyle] = paragraph

    scrollView.documentView = textView
    DispatchQueue.main.async {
      textView.window?.makeFirstResponder(textView)
    }
    return scrollView
  }

  func updateNSView(_ scrollView: NSScrollView, context: Context) {
    guard let textView = scrollView.documentView as? NSTextView,
      textView.string != text
    else { return }
    let selection = textView.selectedRange()
    context.coordinator.isUpdating = true
    textView.string = text
    textView.setSelectedRange(
      NSRange(location: min(selection.location, text.utf16.count), length: 0))
    context.coordinator.isUpdating = false
  }

  final class Coordinator: NSObject, NSTextViewDelegate {
    @Binding private var text: String
    var isUpdating = false

    init(text: Binding<String>) {
      _text = text
    }

    func textDidChange(_ notification: Notification) {
      guard !isUpdating, let textView = notification.object as? NSTextView else { return }
      text = textView.string
    }
  }
}
