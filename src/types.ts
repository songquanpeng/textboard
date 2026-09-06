export type Note = {
  id: string;
  content: string;
  createdAt: number;
  updatedAt: number;
  pinned?: boolean;
};

export type Workspace = {
  version: 1;
  notes: Note[];
  activeNoteId: string | null;
  theme: "light" | "dark" | "system";
};

export type SaveState = "idle" | "saving" | "saved" | "error";
