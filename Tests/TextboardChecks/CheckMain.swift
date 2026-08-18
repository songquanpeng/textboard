import Foundation

enum CheckFailure: Error, CustomStringConvertible {
  case failed(String)

  var description: String {
    switch self {
    case .failed(let message): "检查失败：\(message)"
    }
  }
}

@main
struct TextboardChecks {
  @MainActor
  static func main() throws {
    try legacyWorkspaceCheck()
    try modelCheck()
    try storeCheck()
    print("Textboard checks passed")
  }

  private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else { throw CheckFailure.failed(message) }
  }

  private static func legacyWorkspaceCheck() throws {
    let id = UUID()
    let json = """
      {
        "version": 1,
        "notes": [{
          "id": "\(id.uuidString)",
          "content": "标题\\n正文",
          "createdAt": 1720000000123,
          "updatedAt": 1720000000456,
          "pinned": true
        }],
        "activeNoteId": "\(id.uuidString)",
        "theme": "dark"
      }
      """
    let workspace = try JSONDecoder().decode(Workspace.self, from: Data(json.utf8))
    try expect(workspace.activeNoteId == id, "旧版 activeNoteId 应兼容")
    try expect(workspace.notes.first?.title == "标题", "标题提取错误")
    try expect(workspace.notes.first?.preview == "正文", "摘要提取错误")
    try expect(
      abs((workspace.notes.first?.createdAt.timeIntervalSince1970 ?? 0) - 1_720_000_000.123)
        < 0.001, "毫秒时间戳解码错误")
    try expect(workspace.notes.first?.isPinned == true, "置顶状态解码错误")
    try expect(workspace.theme == .dark, "主题解码错误")

    let encoded = try JSONEncoder().encode(workspace)
    let roundTrip = try JSONDecoder().decode(Workspace.self, from: encoded)
    try expect(roundTrip == workspace, "工作区往返编码不一致")
  }

  private static func modelCheck() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3_600)!
    let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 18, hour: 12))!
    func note(daysAgo: Int, pinned: Bool = false) -> Note {
      let date = calendar.date(byAdding: .day, value: -daysAgo, to: now)!
      return Note(createdAt: date, updatedAt: date, isPinned: pinned)
    }

    try expect(
      NoteMetrics.group(for: note(daysAgo: 0), now: now, calendar: calendar) == .today, "今天分组错误")
    try expect(
      NoteMetrics.group(for: note(daysAgo: 1), now: now, calendar: calendar) == .yesterday, "昨天分组错误"
    )
    try expect(
      NoteMetrics.group(for: note(daysAgo: 6), now: now, calendar: calendar) == .lastSevenDays,
      "七天内分组错误")
    try expect(
      NoteMetrics.group(for: note(daysAgo: 7), now: now, calendar: calendar) == .earlier, "更早分组错误")
    try expect(
      NoteMetrics.group(for: note(daysAgo: 30, pinned: true), now: now, calendar: calendar)
        == .pinned, "置顶分组错误")

    let locale = Locale(identifier: "zh_CN")
    let todayLabel = NoteMetrics.sidebarDate(
      for: note(daysAgo: 0).updatedAt, now: now, calendar: calendar, locale: locale)
    let yesterdayLabel = NoteMetrics.sidebarDate(
      for: note(daysAgo: 1).updatedAt, now: now, calendar: calendar, locale: locale)
    let weekdayLabel = NoteMetrics.sidebarDate(
      for: note(daysAgo: 6).updatedAt, now: now, calendar: calendar, locale: locale)
    let detailLabel = NoteMetrics.detailDate(
      for: note(daysAgo: 0).updatedAt, now: now, calendar: calendar, locale: locale)
    try expect(!todayLabel.isEmpty, "今天的列表时间不能为空")
    try expect(yesterdayLabel == "昨天", "昨天的列表时间错误")
    try expect(!weekdayLabel.isEmpty && weekdayLabel != todayLabel, "七天内的列表时间错误")
    try expect(!detailLabel.isEmpty && detailLabel.contains(":"), "编辑器日期格式错误")

    let counts = NoteMetrics.counts(in: "你好 Swift 6\ntext_board")
    try expect(counts.characters == 18, "字符统计错误")
    try expect(counts.words == 5, "字词统计错误")
  }

  @MainActor
  private static func storeCheck() throws {
    let directory = FileManager.default.temporaryDirectory
      .appending(path: "TextboardChecks-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let fileURL = directory.appending(path: "workspace.json")
    let store = WorkspaceStore(fileURL: fileURL)
    let initialCount = store.workspace.notes.count

    let older = Date(timeIntervalSince1970: 100)
    let newer = Date(timeIntervalSince1970: 200)
    let first = store.createNote(content: "Alpha", now: older)
    let second = store.createNote(content: "alpha beta", now: newer)
    store.togglePin(first)
    store.query = "ALPHA"
    try expect(store.filteredNotes.map(\.id) == [first, second], "搜索或排序错误")

    store.select(second)
    store.updateActiveNote(content: "更新后的内容", now: newer)
    try store.saveImmediately()
    let reloaded = WorkspaceStore(fileURL: fileURL)
    try expect(reloaded.workspace.notes.count == initialCount + 2, "保存后数量错误")
    try expect(reloaded.activeNote?.content == "更新后的内容", "保存后内容错误")

    let removed = try require(reloaded.delete(second), "删除应返回文稿")
    try expect(reloaded.workspace.activeNoteId != second, "删除后仍选中旧文稿")
    reloaded.restore(removed)
    try expect(reloaded.workspace.activeNoteId == second, "恢复后未选中文稿")
  }

  private static func require<T>(_ value: T?, _ message: String) throws -> T {
    guard let value else { throw CheckFailure.failed(message) }
    return value
  }
}
