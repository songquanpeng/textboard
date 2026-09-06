import { useRef, useState, type PointerEvent as ReactPointerEvent } from "react";
import { Pin, Trash2 } from "lucide-react";
import type { Note } from "../types";
import { notePreview, noteTitle, relativeTime } from "../utils";

type Props = {
  note: Note;
  active: boolean;
  onSelect: () => void;
  onDelete: () => void;
};

const DELETE_REVEAL = 62;

export function NoteItem({ note, active, onSelect, onDelete }: Props) {
  const [offset, setOffset] = useState(0);
  const [dragging, setDragging] = useState(false);
  const gesture = useRef({
    pointerId: -1,
    startX: 0,
    startY: 0,
    startOffset: 0,
    currentOffset: 0,
    moved: false,
  });

  const onPointerDown = (event: ReactPointerEvent<HTMLButtonElement>) => {
    if (event.button !== 0) return;
    gesture.current = {
      pointerId: event.pointerId,
      startX: event.clientX,
      startY: event.clientY,
      startOffset: offset,
      currentOffset: offset,
      moved: false,
    };
    setDragging(true);
    event.currentTarget.setPointerCapture(event.pointerId);
  };

  const onPointerMove = (event: ReactPointerEvent<HTMLButtonElement>) => {
    if (gesture.current.pointerId !== event.pointerId) return;
    const deltaX = event.clientX - gesture.current.startX;
    const deltaY = event.clientY - gesture.current.startY;
    if (Math.abs(deltaY) > Math.abs(deltaX) && !gesture.current.moved) return;
    if (Math.abs(deltaX) > 5) gesture.current.moved = true;
    const nextOffset = Math.max(0, Math.min(DELETE_REVEAL, gesture.current.startOffset + deltaX));
    gesture.current.currentOffset = nextOffset;
    setOffset(nextOffset);
  };

  const finishGesture = (event: ReactPointerEvent<HTMLButtonElement>) => {
    if (gesture.current.pointerId !== event.pointerId) return;
    const shouldReveal = gesture.current.currentOffset > DELETE_REVEAL / 2;
    setOffset(shouldReveal ? DELETE_REVEAL : 0);
    setDragging(false);
    gesture.current.pointerId = -1;
  };

  const handleClick = () => {
    if (gesture.current.moved) {
      gesture.current.moved = false;
      return;
    }
    if (offset > 0) {
      setOffset(0);
      return;
    }
    onSelect();
  };

  return (
    <div
      className={`note-item-shell ${dragging ? "is-dragging" : ""} ${offset > 0 ? "has-offset" : ""}`}
    >
      <button
        className="note-item-delete"
        aria-label={`删除 ${noteTitle(note)}`}
        aria-hidden={offset === 0}
        tabIndex={offset > 0 ? 0 : -1}
        style={{ width: `${offset}px` }}
        onClick={() => {
          setOffset(0);
          onDelete();
        }}
      >
        <Trash2 size={16} />
      </button>
      <button
        className={`note-item ${active ? "is-active" : ""}`}
        onClick={handleClick}
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={finishGesture}
        onPointerCancel={finishGesture}
      >
        <span className="note-item__topline">
          <span className="note-item__title">{noteTitle(note)}</span>
          {note.pinned ? <Pin size={12} strokeWidth={2} /> : null}
        </span>
        <span className="note-item__bottomline">
          <span className="note-item__time">{relativeTime(note.updatedAt)}</span>
          <span className="note-item__preview">{notePreview(note)}</span>
        </span>
      </button>
    </div>
  );
}
