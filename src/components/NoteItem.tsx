import { Pin } from "lucide-react";
import type { Note } from "../types";
import { notePreview, noteTitle, relativeTime } from "../utils";

type Props = {
  note: Note;
  active: boolean;
  onSelect: () => void;
};

export function NoteItem({ note, active, onSelect }: Props) {
  return (
    <button className={`note-item ${active ? "is-active" : ""}`} onClick={onSelect}>
      <span className="note-item__topline">
        <span className="note-item__title">{noteTitle(note)}</span>
        {note.pinned ? <Pin size={12} strokeWidth={2} /> : null}
      </span>
      <span className="note-item__bottomline">
        <span className="note-item__time">{relativeTime(note.updatedAt)}</span>
        <span className="note-item__preview">{notePreview(note)}</span>
      </span>
    </button>
  );
}
