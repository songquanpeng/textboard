import { useCallback, useEffect, useMemo, useRef, useState, type MouseEvent as ReactMouseEvent } from "react";
import { getCurrentWindow } from "@tauri-apps/api/window";
import {
  Check,
  FileText,
  Moon,
  MoreHorizontal,
  PanelLeftClose,
  PanelLeftOpen,
  Pin,
  Plus,
  Search,
  Sun,
  Trash2,
  X,
} from "lucide-react";
import { EmptyState } from "./components/EmptyState";
import { IconButton } from "./components/IconButton";
import { NoteItem } from "./components/NoteItem";
import { loadWorkspace, saveWorkspace, saveWorkspaceShadow } from "./storage";
import type { Note, SaveState, Workspace } from "./types";
import { fullDate, getDateGroup, noteStats, noteTitle, type DateGroup } from "./utils";

const GROUP_ORDER: DateGroup[] = ["置顶", "今天", "昨天", "过去 7 天", "更早"];

function newNote(content = ""): Note {
  const now = Date.now();
  return { id: crypto.randomUUID(), content, createdAt: now, updatedAt: now };
}

function initialWorkspace(): Workspace {
  const note = newNote("欢迎来到 Textboard\n\n这里适合放下一些还没想好归宿的文字。\n\n不用保存，输入的内容会自动留在这台设备上。按 ⌘N 新建文稿，⌘K 搜索。");
  return { version: 1, notes: [note], activeNoteId: note.id, theme: "system" };
}

function startWindowDrag(event: ReactMouseEvent<HTMLElement>) {
  if (event.button !== 0 || !("__TAURI_INTERNALS__" in window)) return;
  const target = event.target as HTMLElement;
  if (target.closest("button, input, textarea, [data-no-drag]")) return;
  event.preventDefault();
  void getCurrentWindow().startDragging();
}

export default function App() {
  const [workspace, setWorkspace] = useState<Workspace | null>(null);
  const [query, setQuery] = useState("");
  const [searchOpen, setSearchOpen] = useState(false);
  const [sidebarOpen, setSidebarOpen] = useState(true);
  const [menuOpen, setMenuOpen] = useState(false);
  const [saveState, setSaveState] = useState<SaveState>("idle");
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [alwaysOnTop, setAlwaysOnTop] = useState(false);
  const editorRef = useRef<HTMLTextAreaElement>(null);
  const searchRef = useRef<HTMLInputElement>(null);
  const loadedRef = useRef(false);

  useEffect(() => {
    void loadWorkspace().then((saved) => {
      setWorkspace(saved?.version === 1 ? saved : initialWorkspace());
      loadedRef.current = true;
    });
  }, []);

  useEffect(() => {
    if (!("__TAURI_INTERNALS__" in window)) return;
    void getCurrentWindow().isAlwaysOnTop().then(setAlwaysOnTop);
  }, []);

  useEffect(() => {
    if (!workspace || !loadedRef.current) return;
    saveWorkspaceShadow(workspace);
    setSaveState("saving");
    const timer = window.setTimeout(() => {
      void saveWorkspace(workspace)
        .then(() => setSaveState("saved"))
        .catch(() => setSaveState("error"));
    }, 350);
    return () => window.clearTimeout(timer);
  }, [workspace]);

  useEffect(() => {
    if (!workspace) return;
    const root = document.documentElement;
    root.dataset.theme = workspace.theme;
    const dark = window.matchMedia("(prefers-color-scheme: dark)").matches;
    root.classList.toggle("dark", workspace.theme === "dark" || (workspace.theme === "system" && dark));
  }, [workspace?.theme]);

  const activeNote = workspace?.notes.find((note) => note.id === workspace.activeNoteId) ?? null;

  const createNote = useCallback(() => {
    const note = newNote();
    setWorkspace((current) => current ? { ...current, notes: [note, ...current.notes], activeNoteId: note.id } : current);
    setQuery("");
    setSearchOpen(false);
    setTimeout(() => editorRef.current?.focus(), 40);
  }, []);

  const updateNote = useCallback((noteId: string, patch: Partial<Note>) => {
    setWorkspace((current) => {
      if (!current) return current;
      return {
        ...current,
        notes: current.notes.map((note) =>
          note.id === noteId ? { ...note, ...patch, updatedAt: Date.now() } : note,
        ),
      };
    });
  }, []);

  const selectNote = useCallback((noteId: string) => {
    setWorkspace((current) => current ? { ...current, activeNoteId: noteId } : current);
    setTimeout(() => editorRef.current?.focus(), 20);
  }, []);

  const deleteNote = useCallback((noteId: string) => {
    setWorkspace((current) => {
      if (!current) return current;
      const index = current.notes.findIndex((note) => note.id === noteId);
      if (index < 0) return current;
      const notes = current.notes.filter((note) => note.id !== noteId);
      if (current.activeNoteId !== noteId) return { ...current, notes };
      const next = notes[Math.min(index, notes.length - 1)] ?? null;
      return { ...current, notes, activeNoteId: next?.id ?? null };
    });
    setConfirmDelete(false);
    setMenuOpen(false);
  }, []);

  const toggleAlwaysOnTop = useCallback(() => {
    const next = !alwaysOnTop;
    if (!("__TAURI_INTERNALS__" in window)) {
      setAlwaysOnTop(next);
      return;
    }
    void getCurrentWindow().setAlwaysOnTop(next).then(() => setAlwaysOnTop(next));
  }, [alwaysOnTop]);

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      const command = event.metaKey || event.ctrlKey;
      if (command && event.key.toLowerCase() === "n") {
        event.preventDefault();
        createNote();
      }
      if (command && event.key.toLowerCase() === "k") {
        event.preventDefault();
        setSidebarOpen(true);
        setSearchOpen(true);
        setTimeout(() => searchRef.current?.focus(), 20);
      }
      if (event.key === "Escape") {
        setMenuOpen(false);
        setConfirmDelete(false);
        if (searchOpen) {
          setSearchOpen(false);
          setQuery("");
          editorRef.current?.focus();
        }
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [createNote, searchOpen]);

  const filteredNotes = useMemo(() => {
    if (!workspace) return [];
    const normalized = query.trim().toLocaleLowerCase();
    return workspace.notes
      .filter((note) => !normalized || note.content.toLocaleLowerCase().includes(normalized))
      .sort((a, b) => Number(Boolean(b.pinned)) - Number(Boolean(a.pinned)) || b.updatedAt - a.updatedAt);
  }, [workspace, query]);

  const groupedNotes = useMemo(() => {
    return GROUP_ORDER.map((group) => ({
      group,
      notes: filteredNotes.filter((note) => getDateGroup(note) === group),
    })).filter(({ notes }) => notes.length);
  }, [filteredNotes]);

  if (!workspace) {
    return <div className="loading-screen"><span /></div>;
  }

  const stats = noteStats(activeNote?.content ?? "");
  const isDark = workspace.theme === "dark" || (
    workspace.theme === "system" && window.matchMedia("(prefers-color-scheme: dark)").matches
  );

  return (
    <div className={`app-shell ${sidebarOpen ? "" : "sidebar-collapsed"}`}>
      <aside className="sidebar">
        <div className="window-drag-region" onMouseDown={startWindowDrag} />
        <div className="sidebar__header" onMouseDown={startWindowDrag}>
          <div className="brand">
            <span className="brand__mark"><FileText size={14} /></span>
            <span>Textboard</span>
          </div>
          <IconButton label="收起侧边栏" onClick={() => setSidebarOpen(false)}>
            <PanelLeftClose size={17} />
          </IconButton>
        </div>

        <div className="sidebar__actions">
          <button className="new-note-button" onClick={createNote}>
            <Plus size={16} strokeWidth={2.2} />
            <span>新建文稿</span>
            <kbd>⌘ N</kbd>
          </button>
          {searchOpen ? (
            <div className="search-box is-open">
              <Search size={15} />
              <input
                ref={searchRef}
                value={query}
                onChange={(event) => setQuery(event.target.value)}
                placeholder="搜索所有文稿"
                autoFocus
              />
              <button onClick={() => { setQuery(""); setSearchOpen(false); }} aria-label="关闭搜索"><X size={14} /></button>
            </div>
          ) : (
            <button className="search-box" onClick={() => { setSearchOpen(true); setTimeout(() => searchRef.current?.focus(), 20); }}>
              <Search size={15} />
              <span>搜索</span>
              <kbd>⌘ K</kbd>
            </button>
          )}
        </div>

        <div className="note-list">
          {groupedNotes.length ? groupedNotes.map(({ group, notes }) => (
            <section className="note-group" key={group}>
              <h2>{group}</h2>
              {notes.map((note) => (
                <NoteItem
                  key={note.id}
                  note={note}
                  active={note.id === workspace.activeNoteId}
                  onSelect={() => selectNote(note.id)}
                  onDelete={() => deleteNote(note.id)}
                />
              ))}
            </section>
          )) : (
            <div className="no-results">
              <Search size={19} />
              <p>没有找到相关文稿</p>
            </div>
          )}
        </div>

        <div className="sidebar__footer">
          <span>{workspace.notes.length} 篇文稿</span>
          <IconButton
            label={isDark ? "切换浅色模式" : "切换深色模式"}
            onClick={() => setWorkspace((current) => current ? { ...current, theme: isDark ? "light" : "dark" } : current)}
          >
            {isDark ? <Sun size={15} /> : <Moon size={15} />}
          </IconButton>
        </div>
      </aside>

      <section className="content-panel">
        <header className="editor-toolbar" onMouseDown={startWindowDrag}>
          <div className="toolbar__left">
            {!sidebarOpen ? (
              <IconButton label="展开侧边栏" onClick={() => setSidebarOpen(true)}>
                <PanelLeftOpen size={18} />
              </IconButton>
            ) : null}
            {activeNote ? <span className="document-date">{fullDate(activeNote.createdAt)}</span> : null}
          </div>
          <div className="toolbar__right">
            <IconButton
              label={alwaysOnTop ? "取消始终置顶" : "始终置顶"}
              className={alwaysOnTop ? "is-active" : ""}
              aria-pressed={alwaysOnTop}
              onClick={toggleAlwaysOnTop}
            >
              <Pin size={16} />
            </IconButton>
            <span className={`save-status save-status--${saveState}`}>
              {saveState === "saving" ? "正在保存…" : saveState === "error" ? "保存失败" : <><Check size={13} /> 已保存</>}
            </span>
            {activeNote ? (
              <div className="more-menu-wrap">
                <IconButton label="更多操作" onClick={() => { setMenuOpen(!menuOpen); setConfirmDelete(false); }}>
                  <MoreHorizontal size={19} />
                </IconButton>
                {menuOpen ? (
                  <div className="popover-menu">
                    <button onClick={() => { updateNote(activeNote.id, { pinned: !activeNote.pinned }); setMenuOpen(false); }}>
                      <Pin size={15} /> {activeNote.pinned ? "取消置顶" : "置顶文稿"}
                    </button>
                    <button className="danger" onClick={() => setConfirmDelete(true)}>
                      <Trash2 size={15} /> 删除文稿
                    </button>
                  </div>
                ) : null}
              </div>
            ) : null}
          </div>
        </header>

        {activeNote ? (
          <main className="editor-wrap">
            <textarea
              ref={editorRef}
              key={activeNote.id}
              className="editor"
              value={activeNote.content}
              onChange={(event) => updateNote(activeNote.id, { content: event.target.value })}
              placeholder="从这里开始…"
              spellCheck="false"
              autoFocus
            />
            <footer className="editor-footer">
              <span>{stats.characters} 字符</span>
              <span className="footer-divider" />
              <span>{stats.words} 字词</span>
            </footer>
          </main>
        ) : <EmptyState onCreate={createNote} />}

        {confirmDelete && activeNote ? (
          <div className="modal-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) setConfirmDelete(false); }}>
            <div className="confirm-dialog" role="alertdialog" aria-modal="true">
              <div className="dialog-icon"><Trash2 size={20} /></div>
              <h2>删除这篇文稿？</h2>
              <p>“{noteTitle(activeNote)}” 将从这台设备上移除，此操作无法撤销。</p>
              <div className="dialog-actions">
                <button onClick={() => setConfirmDelete(false)}>取消</button>
                <button className="danger-button" onClick={() => deleteNote(activeNote.id)}>删除</button>
              </div>
            </div>
          </div>
        ) : null}
      </section>
    </div>
  );
}
