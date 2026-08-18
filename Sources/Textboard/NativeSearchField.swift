import AppKit
import SwiftUI

struct NativeSearchField: NSViewRepresentable {
  @Binding var text: String
  let focusRequest: Int

  func makeCoordinator() -> Coordinator {
    Coordinator(text: $text, focusRequest: focusRequest)
  }

  func makeNSView(context: Context) -> NSSearchField {
    let searchField = NSSearchField()
    searchField.delegate = context.coordinator
    searchField.placeholderString = "搜索所有文稿"
    searchField.sendsSearchStringImmediately = true
    searchField.sendsWholeSearchString = false
    searchField.controlSize = .large
    searchField.font = .systemFont(ofSize: NSFont.systemFontSize)
    searchField.setAccessibilityLabel("搜索所有文稿")
    return searchField
  }

  func updateNSView(_ searchField: NSSearchField, context: Context) {
    if searchField.stringValue != text {
      searchField.stringValue = text
    }

    guard context.coordinator.focusRequest != focusRequest else { return }
    context.coordinator.focusRequest = focusRequest
    DispatchQueue.main.async {
      searchField.window?.makeFirstResponder(searchField)
      searchField.selectText(nil)
    }
  }

  final class Coordinator: NSObject, NSSearchFieldDelegate {
    @Binding private var text: String
    var focusRequest: Int

    init(text: Binding<String>, focusRequest: Int) {
      _text = text
      self.focusRequest = focusRequest
    }

    func controlTextDidChange(_ notification: Notification) {
      guard let searchField = notification.object as? NSSearchField else { return }
      text = searchField.stringValue
    }
  }
}
