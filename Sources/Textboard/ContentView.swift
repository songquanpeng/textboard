import AppKit
import SwiftUI

struct ContentView: View {
  @ObservedObject var store: WorkspaceStore
  @Environment(\.undoManager) private var undoManager
  @State private var deletionCandidate: Note?

  private var preferredColorScheme: ColorScheme? {
    switch store.workspace.theme {
    case .system: nil
    case .light: .light
    case .dark: .dark
    }
  }

  var body: some View {
    NavigationSplitView {
      SidebarView(store: store, deletionCandidate: $deletionCandidate)
        .navigationSplitViewColumnWidth(min: 220, ideal: 270, max: 340)
    } detail: {
      editor
    }
    .background(WindowAccessor { store.attach(window: $0) })
    .preferredColorScheme(preferredColorScheme)
    .alert("删除这篇文稿？", isPresented: deletionPresented, presenting: deletionCandidate) { note in
      Button("取消", role: .cancel) {}
      Button("删除", role: .destructive) { delete(note) }
    } message: { note in
      Text("“\(note.title)”将从这台 Mac 上移除。")
    }
  }

  @ViewBuilder
  private var editor: some View {
    if let note = store.activeNote {
      NoteEditorView(store: store, note: note, deletionCandidate: $deletionCandidate)
        .id(note.id)
    } else {
      ContentUnavailableView {
        Label("没有文稿", systemImage: "doc.text")
      } description: {
        Text("新建一篇文稿，随手记下文字。")
      } actions: {
        Button("新建文稿") { store.createNote() }
          .keyboardShortcut("n", modifiers: .command)
      }
    }
  }

  private var deletionPresented: Binding<Bool> {
    Binding(
      get: { deletionCandidate != nil },
      set: { if !$0 { deletionCandidate = nil } }
    )
  }

  private func delete(_ note: Note) {
    guard let removed = store.delete(note.id) else { return }
    undoManager?.registerUndo(withTarget: store) { target in
      MainActor.assumeIsolated {
        target.restore(removed)
      }
    }
    undoManager?.setActionName("删除文稿")
    deletionCandidate = nil
  }
}

private struct SidebarView: View {
  @ObservedObject var store: WorkspaceStore
  @Binding var deletionCandidate: Note?
  @FocusState private var searchFocused: Bool

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 8) {
        Image(systemName: "magnifyingglass")
          .foregroundStyle(.secondary)
        TextField("搜索所有文稿", text: $store.query)
          .textFieldStyle(.plain)
          .focused($searchFocused)
        if !store.query.isEmpty {
          Button {
            store.query = ""
          } label: {
            Image(systemName: "xmark.circle.fill")
              .foregroundStyle(.tertiary)
          }
          .buttonStyle(.plain)
          .accessibilityLabel("清除搜索")
        }
      }
      .padding(.horizontal, 10)
      .frame(height: 30)
      .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 7))
      .padding(.horizontal, 10)
      .padding(.vertical, 8)

      List {
        ForEach(DateGroup.allCases) { group in
          let notes = store.notes(in: group)
          if !notes.isEmpty {
            Section(group.title) {
              ForEach(notes) { note in
                Button {
                  store.select(note.id)
                } label: {
                  NoteRow(note: note)
                }
                .buttonStyle(.plain)
                .listRowBackground(
                  store.workspace.activeNoteId == note.id
                    ? Color.accentColor.opacity(0.16)
                    : Color.clear
                )
                .contextMenu {
                  Button(note.isPinned ? "取消置顶" : "置顶文稿", systemImage: "pin") {
                    store.togglePin(note.id)
                  }
                  Divider()
                  Button("删除文稿", systemImage: "trash", role: .destructive) {
                    deletionCandidate = note
                  }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                  Button("删除", systemImage: "trash", role: .destructive) {
                    deletionCandidate = note
                  }
                }
              }
            }
          }
        }
      }
      .listStyle(.sidebar)
      .overlay {
        if store.filteredNotes.isEmpty {
          ContentUnavailableView.search(text: store.query)
        }
      }

      Divider()
      HStack {
        Text("\(store.workspace.notes.count) 篇文稿")
          .foregroundStyle(.secondary)
        Spacer()
        Button {
          store.createNote()
        } label: {
          Image(systemName: "square.and.pencil")
        }
        .buttonStyle(.borderless)
        .help("新建文稿 (⌘N)")
        .accessibilityLabel("新建文稿")
      }
      .font(.caption)
      .padding(.horizontal, 12)
      .frame(height: 35)
    }
    .navigationTitle("Textboard")
    .onChange(of: store.searchRequest) {
      searchFocused = true
    }
  }

}

private struct NoteRow: View {
  let note: Note

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 5) {
        Text(note.title)
          .font(.body.weight(.medium))
          .lineLimit(1)
        Spacer(minLength: 4)
        if note.isPinned {
          Image(systemName: "pin.fill")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
      HStack(spacing: 6) {
        Text(note.updatedAt, style: .relative)
          .foregroundStyle(.secondary)
        Text(note.preview)
          .foregroundStyle(.tertiary)
          .lineLimit(1)
      }
      .font(.caption)
    }
    .padding(.vertical, 3)
    .accessibilityElement(children: .combine)
  }
}

private struct NoteEditorView: View {
  @ObservedObject var store: WorkspaceStore
  let note: Note
  @Binding var deletionCandidate: Note?

  private var content: Binding<String> {
    Binding(
      get: { store.activeNote?.content ?? "" },
      set: { store.updateActiveNote(content: $0) }
    )
  }

  var body: some View {
    NativeTextEditor(text: content)
      .safeAreaInset(edge: .bottom, spacing: 0) {
        footer
      }
      .navigationTitle(note.title)
      .toolbar {
        ToolbarItem(placement: .navigation) {
          Text(note.createdAt.formatted(date: .long, time: .shortened))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        ToolbarItemGroup(placement: .primaryAction) {
          Button {
            store.isAlwaysOnTop.toggle()
          } label: {
            Label(
              store.isAlwaysOnTop ? "取消始终置顶" : "始终置顶",
              systemImage: store.isAlwaysOnTop ? "pin.fill" : "pin"
            )
          }
          .help(store.isAlwaysOnTop ? "取消始终置顶" : "始终置顶")

          Menu {
            Button(note.isPinned ? "取消置顶" : "置顶文稿", systemImage: "pin") {
              store.togglePin(note.id)
            }
            Divider()
            Button("删除文稿", systemImage: "trash", role: .destructive) {
              deletionCandidate = note
            }
          } label: {
            Label("更多", systemImage: "ellipsis.circle")
          }
        }
      }
  }

  private var footer: some View {
    let counts = NoteMetrics.counts(in: store.activeNote?.content ?? "")
    return HStack(spacing: 8) {
      saveStatus
      Spacer()
      Text("\(counts.characters) 字符")
      Text("·")
        .foregroundStyle(.quaternary)
      Text("\(counts.words) 字词")
    }
    .font(.caption)
    .foregroundStyle(.secondary)
    .padding(.horizontal, 16)
    .frame(height: 30)
    .background(.bar)
  }

  @ViewBuilder
  private var saveStatus: some View {
    switch store.saveState {
    case .idle, .saved:
      Label("已保存", systemImage: "checkmark")
    case .saving:
      Text("正在保存…")
    case .failed:
      Label("保存失败", systemImage: "exclamationmark.triangle")
        .foregroundStyle(.red)
    }
  }
}

private struct WindowAccessor: NSViewRepresentable {
  let onResolve: (NSWindow) -> Void

  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    DispatchQueue.main.async {
      if let window = view.window { onResolve(window) }
    }
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    DispatchQueue.main.async {
      if let window = nsView.window { onResolve(window) }
    }
  }
}
