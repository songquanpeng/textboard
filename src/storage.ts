import { invoke } from "@tauri-apps/api/core";
import type { Workspace } from "./types";

const FALLBACK_KEY = "moment-workspace-v1";

function isTauri() {
  return "__TAURI_INTERNALS__" in window;
}

export function saveWorkspaceShadow(workspace: Workspace): void {
  localStorage.setItem(FALLBACK_KEY, JSON.stringify(workspace));
}

export async function loadWorkspace(): Promise<Workspace | null> {
  try {
    const fallbackRaw = localStorage.getItem(FALLBACK_KEY);
    const fallback = fallbackRaw ? (JSON.parse(fallbackRaw) as Workspace) : null;

    if (isTauri()) {
      const raw = await invoke<string | null>("load_workspace");
      const disk = raw ? (JSON.parse(raw) as Workspace) : null;
      if (!disk) return fallback;
      if (!fallback) return disk;

      const latestUpdate = (workspace: Workspace) =>
        Math.max(0, ...workspace.notes.map((note) => note.updatedAt));
      return latestUpdate(fallback) > latestUpdate(disk) ? fallback : disk;
    }

    return fallback;
  } catch (error) {
    console.error("Failed to load workspace", error);
    return null;
  }
}

export async function saveWorkspace(workspace: Workspace): Promise<void> {
  const raw = JSON.stringify(workspace);
  // A synchronous shadow copy protects the last keystrokes if the window is
  // closed before the debounced Rust file write has time to finish.
  saveWorkspaceShadow(workspace);
  if (isTauri()) {
    await invoke("save_workspace", { contents: raw });
  }
}
