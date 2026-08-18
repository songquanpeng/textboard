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

  var body: some View {
    VStack(spacing: 0) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text("文稿")
          .font(.title2.weight(.semibold))
        Text("\(store.workspace.notes.count)")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .monospacedDigit()
        Spacer()
      }
      .padding(.horizontal, 14)
      .padding(.top, 10)
      .padding(.bottom, 8)

      NativeSearchField(text: $store.query, focusRequest: store.searchRequest)
        .frame(height: 28)
        .padding(.horizontal, 10)
        .padding(.bottom, 9)

      List {
        ForEach(DateGroup.allCases) { group in
          let notes = store.notes(in: group)
          if !notes.isEmpty {
            Section(group.title) {
              ForEach(notes) { note in
                NoteRowButton(
                  note: note,
                  isSelected: store.workspace.activeNoteId == note.id,
                  onSelect: { store.select(note.id) },
                  onTogglePin: { store.togglePin(note.id) },
                  onDelete: { deletionCandidate = note }
                )
              }
            }
          }
        }
      }
      .listStyle(.sidebar)
      .scrollContentBackground(.hidden)
      .overlay {
        if store.filteredNotes.isEmpty {
          ContentUnavailableView.search(text: store.query)
        }
      }
    }
    .navigationTitle("Textboard")
  }

}

private struct NoteRowButton: View {
  let note: Note
  let isSelected: Bool
  let onSelect: () -> Void
  let onTogglePin: () -> Void
  let onDelete: () -> Void
  @Environment(\.colorScheme) private var colorScheme
  @State private var isHovering = false

  var body: some View {
    Button(action: onSelect) {
      NoteRow(note: note)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
    .buttonStyle(.plain)
    .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6))
    .listRowSeparator(.hidden)
    .listRowBackground(Color.clear)
    .onHover { isHovering = $0 }
    .contextMenu {
      Button(note.isPinned ? "取消置顶" : "置顶文稿", systemImage: "pin", action: onTogglePin)
      Divider()
      Button("删除文稿", systemImage: "trash", role: .destructive, action: onDelete)
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      Button("删除", systemImage: "trash", role: .destructive, action: onDelete)
    }
  }

  private var rowBackground: Color {
    if isSelected {
      return Color.accentColor.opacity(colorScheme == .dark ? 0.30 : 0.17)
    }
    if isHovering {
      return Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05)
    }
    return .clear
  }
}

private struct NoteRow: View {
  let note: Note

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack(spacing: 5) {
        Text(note.title)
          .font(.system(size: 13, weight: .semibold))
          .lineLimit(1)
        Spacer(minLength: 4)
        if note.isPinned {
          Image(systemName: "pin.fill")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
      HStack(spacing: 6) {
        Text(NoteMetrics.sidebarDate(for: note.updatedAt))
          .foregroundStyle(.secondary)
          .monospacedDigit()
        Text(note.preview)
          .foregroundStyle(.tertiary)
          .lineLimit(1)
      }
      .font(.system(size: 11))
    }
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
      .background(Color(nsColor: .textBackgroundColor))
      .navigationTitle("")
      .toolbar {
        ToolbarItem(placement: .principal) {
          VStack(spacing: 1) {
            Text(note.title)
              .font(.headline)
              .lineLimit(1)
            Text(NoteMetrics.detailDate(for: note.updatedAt))
              .font(.caption2)
              .foregroundStyle(.secondary)
              .monospacedDigit()
          }
          .accessibilityElement(children: .combine)
        }
        ToolbarItemGroup(placement: .primaryAction) {
          Button {
            store.createNote()
          } label: {
            Label("新建文稿", systemImage: "square.and.pencil")
          }
          .help("新建文稿 (⌘N)")

          Button {
            store.isAlwaysOnTop.toggle()
          } label: {
            Label(
              store.isAlwaysOnTop ? "取消始终置顶" : "始终置顶",
              systemImage: "macwindow.on.rectangle"
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
            Label("更多", systemImage: "ellipsis")
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
    .foregroundStyle(.tertiary)
    .padding(.horizontal, 14)
    .frame(height: 27)
    .background(.ultraThinMaterial)
    .overlay(alignment: .top) {
      Divider()
    }
  }

  @ViewBuilder
  private var saveStatus: some View {
    switch store.saveState {
    case .idle, .saved:
      Label("已保存", systemImage: "checkmark.circle.fill")
    case .saving:
      HStack(spacing: 5) {
        ProgressView()
          .controlSize(.mini)
        Text("正在保存…")
      }
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
