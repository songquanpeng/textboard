import AppKit
import SwiftUI

@main
struct TextboardApp: App {
  @NSApplicationDelegateAdaptor(TextboardAppDelegate.self) private var appDelegate
  @StateObject private var store: WorkspaceStore

  init() {
    let workspaceStore = WorkspaceStore()
    _store = StateObject(wrappedValue: workspaceStore)
    TextboardAppDelegate.pendingStore = workspaceStore
  }

  var body: some Scene {
    WindowGroup {
      ContentView(store: store)
        .frame(minWidth: 760, minHeight: 500)
    }
    .defaultSize(width: 1_060, height: 720)
    .commands {
      TextboardCommands(store: store)
    }

    Settings {
      SettingsView(store: store)
    }
  }
}

@MainActor
final class TextboardAppDelegate: NSObject, NSApplicationDelegate {
  static weak var pendingStore: WorkspaceStore?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.appearance = nil
  }

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    do {
      try Self.pendingStore?.saveImmediately()
      return .terminateNow
    } catch {
      let alert = NSAlert(error: error)
      alert.messageText = "无法保存文稿"
      alert.informativeText = "退出前保存失败。你可以取消退出并重试。\n\n\(error.localizedDescription)"
      alert.addButton(withTitle: "取消退出")
      alert.addButton(withTitle: "仍然退出")
      return alert.runModal() == .alertFirstButtonReturn ? .terminateCancel : .terminateNow
    }
  }
}

private struct TextboardCommands: Commands {
  @ObservedObject var store: WorkspaceStore

  var body: some Commands {
    CommandGroup(replacing: .newItem) {
      Button("新建文稿") { store.createNote() }
        .keyboardShortcut("n", modifiers: .command)
    }

    CommandGroup(after: .textEditing) {
      Button("搜索文稿") { store.requestSearch() }
        .keyboardShortcut("f", modifiers: .command)
      Button("快速搜索") { store.requestSearch() }
        .keyboardShortcut("k", modifiers: .command)
    }

    CommandMenu("文稿") {
      Button(store.activeNote?.isPinned == true ? "取消置顶" : "置顶文稿") {
        if let id = store.workspace.activeNoteId { store.togglePin(id) }
      }
      .disabled(store.activeNote == nil)

      Divider()

      Button(store.isAlwaysOnTop ? "取消始终置顶" : "始终置顶") {
        store.isAlwaysOnTop.toggle()
      }
    }

    CommandMenu("外观") {
      ForEach(AppTheme.allCases) { theme in
        Button {
          store.setTheme(theme)
        } label: {
          if store.workspace.theme == theme {
            Label(theme.title, systemImage: "checkmark")
          } else {
            Text(theme.title)
          }
        }
      }
    }
  }

}

private struct SettingsView: View {
  @ObservedObject var store: WorkspaceStore

  var body: some View {
    Form {
      Picker("外观", selection: theme) {
        ForEach(AppTheme.allCases) { theme in
          Text(theme.title).tag(theme)
        }
      }
      .pickerStyle(.segmented)
    }
    .formStyle(.grouped)
    .padding(20)
    .frame(width: 360)
  }

  private var theme: Binding<AppTheme> {
    Binding(get: { store.workspace.theme }, set: { store.setTheme($0) })
  }
}
