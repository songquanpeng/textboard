import AppKit
import Combine
import Foundation

@MainActor
final class WorkspaceStore: ObservableObject {
  enum SaveState: Equatable {
    case idle
    case saving
    case saved
    case failed(String)
  }

  static let bundleIdentifier = "com.justsong.textboard"

  @Published private(set) var workspace: Workspace
  @Published private(set) var saveState: SaveState = .idle
  @Published var query = ""
  @Published var isAlwaysOnTop = false {
    didSet { window?.level = isAlwaysOnTop ? .floating : .normal }
  }
  @Published var searchRequest = 0

  private let fileURL: URL
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder
  private var saveTask: Task<Void, Never>?
  private weak var window: NSWindow?

  init(fileURL: URL? = nil) {
    encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    decoder = JSONDecoder()
    self.fileURL = fileURL ?? Self.defaultFileURL()

    do {
      let data = try Data(contentsOf: self.fileURL)
      let decoded = try decoder.decode(Workspace.self, from: data)
      workspace = decoded.version == 1 ? decoded : .initial()
      if workspace.activeNoteId.flatMap({ id in workspace.notes.contains { $0.id == id } }) != true
      {
        workspace.activeNoteId = workspace.notes.first?.id
      }
    } catch {
      workspace = .initial()
    }
  }

  deinit {
    saveTask?.cancel()
  }

  static func defaultFileURL(fileManager: FileManager = .default) -> URL {
    if let override = ProcessInfo.processInfo.environment["TEXTBOARD_DATA_PATH"], !override.isEmpty
    {
      return URL(filePath: override, directoryHint: .notDirectory)
    }
    let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    return support.appending(path: bundleIdentifier, directoryHint: .isDirectory)
      .appending(path: "workspace.json", directoryHint: .notDirectory)
  }

  var activeNote: Note? {
    guard let id = workspace.activeNoteId else { return nil }
    return workspace.notes.first { $0.id == id }
  }

  var filteredNotes: [Note] {
    let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
    return workspace.notes
      .filter { normalized.isEmpty || $0.content.localizedCaseInsensitiveContains(normalized) }
      .sorted {
        if $0.isPinned != $1.isPinned { return $0.isPinned }
        return $0.updatedAt > $1.updatedAt
      }
  }

  func notes(in group: DateGroup, now: Date = .now) -> [Note] {
    filteredNotes.filter { NoteMetrics.group(for: $0, now: now) == group }
  }

  func select(_ id: UUID?) {
    workspace.activeNoteId = id
    scheduleSave()
  }

  @discardableResult
  func createNote(content: String = "", now: Date = .now) -> UUID {
    let note = Note(content: content, createdAt: now, updatedAt: now)
    workspace.notes.insert(note, at: 0)
    workspace.activeNoteId = note.id
    query = ""
    scheduleSave()
    return note.id
  }

  func updateActiveNote(content: String, now: Date = .now) {
    guard let id = workspace.activeNoteId,
      let index = workspace.notes.firstIndex(where: { $0.id == id }),
      workspace.notes[index].content != content
    else { return }
    workspace.notes[index].content = content
    workspace.notes[index].updatedAt = now
    scheduleSave()
  }

  func togglePin(_ id: UUID) {
    guard let index = workspace.notes.firstIndex(where: { $0.id == id }) else { return }
    workspace.notes[index].isPinned.toggle()
    workspace.notes[index].updatedAt = .now
    scheduleSave()
  }

  @discardableResult
  func delete(_ id: UUID) -> Note? {
    guard let index = workspace.notes.firstIndex(where: { $0.id == id }) else { return nil }
    let removed = workspace.notes.remove(at: index)
    if workspace.activeNoteId == id {
      workspace.activeNoteId =
        workspace.notes.indices.contains(index)
        ? workspace.notes[index].id
        : workspace.notes.last?.id
    }
    scheduleSave()
    return removed
  }

  func restore(_ note: Note) {
    workspace.notes.append(note)
    workspace.activeNoteId = note.id
    scheduleSave()
  }

  func setTheme(_ theme: AppTheme) {
    workspace.theme = theme
    scheduleSave()
  }

  func requestSearch() {
    searchRequest &+= 1
  }

  func attach(window: NSWindow) {
    self.window = window
    window.title = activeNote?.title ?? "Textboard"
    window.titleVisibility = .hidden
    window.level = isAlwaysOnTop ? .floating : .normal
  }

  func saveImmediately() throws {
    saveTask?.cancel()
    let data = try encoder.encode(workspace)
    let directory = fileURL.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try data.write(to: fileURL, options: .atomic)
    saveState = .saved
  }

  private func scheduleSave() {
    saveTask?.cancel()
    saveState = .saving
    saveTask = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(350))
      guard !Task.isCancelled, let self else { return }
      do {
        try saveImmediately()
      } catch {
        saveState = .failed(error.localizedDescription)
      }
    }
  }
}
