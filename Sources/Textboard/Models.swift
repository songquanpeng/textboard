import Foundation

enum AppTheme: String, Codable, CaseIterable, Identifiable {
  case system
  case light
  case dark

  var id: Self { self }

  var title: String {
    switch self {
    case .system: "跟随系统"
    case .light: "浅色"
    case .dark: "深色"
    }
  }
}

struct Note: Identifiable, Equatable, Sendable {
  var id: UUID
  var content: String
  var createdAt: Date
  var updatedAt: Date
  var isPinned: Bool

  init(
    id: UUID = UUID(),
    content: String = "",
    createdAt: Date = .now,
    updatedAt: Date = .now,
    isPinned: Bool = false
  ) {
    self.id = id
    self.content = content
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.isPinned = isPinned
  }

  var title: String {
    content
      .split(separator: "\n", omittingEmptySubsequences: false)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .first(where: { !$0.isEmpty })?
      .prefix(48)
      .description ?? "无标题"
  }

  var preview: String {
    let lines =
      content
      .split(separator: "\n", omittingEmptySubsequences: false)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
    let remainder = lines.dropFirst().joined(separator: " ")
    return remainder.isEmpty ? "开始写点什么…" : String(remainder.prefix(68))
  }
}

extension Note: Codable {
  private enum CodingKeys: String, CodingKey {
    case id, content, createdAt, updatedAt, pinned
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    id = try values.decode(UUID.self, forKey: .id)
    content = try values.decode(String.self, forKey: .content)
    createdAt = Date(
      timeIntervalSince1970: try values.decode(Double.self, forKey: .createdAt) / 1_000)
    updatedAt = Date(
      timeIntervalSince1970: try values.decode(Double.self, forKey: .updatedAt) / 1_000)
    isPinned = try values.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
  }

  func encode(to encoder: Encoder) throws {
    var values = encoder.container(keyedBy: CodingKeys.self)
    try values.encode(id, forKey: .id)
    try values.encode(content, forKey: .content)
    try values.encode(createdAt.timeIntervalSince1970 * 1_000, forKey: .createdAt)
    try values.encode(updatedAt.timeIntervalSince1970 * 1_000, forKey: .updatedAt)
    if isPinned {
      try values.encode(true, forKey: .pinned)
    }
  }
}

struct Workspace: Codable, Equatable, Sendable {
  var version: Int
  var notes: [Note]
  var activeNoteId: UUID?
  var theme: AppTheme

  static func initial(now: Date = .now) -> Workspace {
    let note = Note(
      content: "欢迎来到 Textboard\n\n这里适合放下一些还没想好归宿的文字。\n\n不用保存，输入的内容会自动留在这台设备上。按 ⌘N 新建文稿，⌘F 搜索。",
      createdAt: now,
      updatedAt: now
    )
    return Workspace(version: 1, notes: [note], activeNoteId: note.id, theme: .system)
  }
}

enum DateGroup: Int, CaseIterable, Identifiable {
  case pinned
  case today
  case yesterday
  case lastSevenDays
  case earlier

  var id: Self { self }

  var title: String {
    switch self {
    case .pinned: "置顶"
    case .today: "今天"
    case .yesterday: "昨天"
    case .lastSevenDays: "过去 7 天"
    case .earlier: "更早"
    }
  }
}

enum NoteMetrics {
  static func group(for note: Note, now: Date = .now, calendar: Calendar = .current) -> DateGroup {
    if note.isPinned { return .pinned }
    let today = calendar.startOfDay(for: now)
    let noteDay = calendar.startOfDay(for: note.updatedAt)
    let days = calendar.dateComponents([.day], from: noteDay, to: today).day ?? 0
    if days <= 0 { return .today }
    if days == 1 { return .yesterday }
    if days < 7 { return .lastSevenDays }
    return .earlier
  }

  static func counts(in content: String) -> (characters: Int, words: Int) {
    let characters = content.filter { !$0.isWhitespace }.count
    let words = content.matches(of: /[\p{Han}]|[\p{L}\p{N}_'-]+/).count
    return (characters, words)
  }

  static func sidebarDate(
    for date: Date,
    now: Date = .now,
    calendar: Calendar = .current,
    locale: Locale = .current
  ) -> String {
    if calendar.isDate(date, inSameDayAs: now) {
      return formatted(date, template: "jm", locale: locale)
    }
    if calendar.isDateInYesterday(date) {
      return "昨天"
    }

    let noteDay = calendar.startOfDay(for: date)
    let today = calendar.startOfDay(for: now)
    let days = calendar.dateComponents([.day], from: noteDay, to: today).day ?? 0
    if days < 7 {
      return formatted(date, template: "EEE", locale: locale)
    }
    if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
      return formatted(date, template: "MMMd", locale: locale)
    }
    return formatted(date, template: "yMMMd", locale: locale)
  }

  static func detailDate(
    for date: Date,
    now: Date = .now,
    calendar: Calendar = .current,
    locale: Locale = .current
  ) -> String {
    let template =
      calendar.component(.year, from: date) == calendar.component(.year, from: now)
      ? "MMMdjm"
      : "yMMMdjm"
    return formatted(date, template: template, locale: locale)
  }

  private static func formatted(_ date: Date, template: String, locale: Locale) -> String {
    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.setLocalizedDateFormatFromTemplate(template)
    return formatter.string(from: date)
  }
}
