import type { Note } from "./types";

export type DateGroup = "置顶" | "今天" | "昨天" | "过去 7 天" | "更早";

export function noteTitle(note: Note) {
  const firstLine = note.content
    .split("\n")
    .map((line) => line.trim())
    .find(Boolean);
  return firstLine?.slice(0, 48) || "无标题";
}

export function notePreview(note: Note) {
  const lines = note.content
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean);
  return lines.slice(1).join(" ").slice(0, 68) || "开始写点什么…";
}

export function noteStats(content: string) {
  const characters = content.replace(/\s/g, "").length;
  const words = (content.match(/[\p{Script=Han}]|[\p{L}\p{N}_'-]+/gu) || []).length;
  return { characters, words };
}

export function getDateGroup(note: Note): DateGroup {
  if (note.pinned) return "置顶";
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
  const noteDay = new Date(note.updatedAt);
  const start = new Date(noteDay.getFullYear(), noteDay.getMonth(), noteDay.getDate()).getTime();
  const diff = Math.round((today - start) / 86_400_000);
  if (diff <= 0) return "今天";
  if (diff === 1) return "昨天";
  if (diff < 7) return "过去 7 天";
  return "更早";
}

export function relativeTime(timestamp: number) {
  const seconds = Math.round((timestamp - Date.now()) / 1000);
  const abs = Math.abs(seconds);
  const formatter = new Intl.RelativeTimeFormat("zh-CN", { numeric: "auto" });
  if (abs < 60) return "刚刚";
  if (abs < 3600) return formatter.format(Math.round(seconds / 60), "minute");
  if (abs < 86_400) return formatter.format(Math.round(seconds / 3600), "hour");
  return new Intl.DateTimeFormat("zh-CN", { month: "short", day: "numeric" }).format(timestamp);
}

export function fullDate(timestamp: number) {
  return new Intl.DateTimeFormat("zh-CN", {
    year: "numeric",
    month: "long",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  }).format(timestamp);
}
