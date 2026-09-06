import { FilePlus2 } from "lucide-react";

export function EmptyState({ onCreate }: { onCreate: () => void }) {
  return (
    <main className="empty-state">
      <div className="empty-state__icon">
        <FilePlus2 size={26} strokeWidth={1.6} />
      </div>
      <h2>留下一点什么</h2>
      <p>灵感、链接、待办，随手放在这里。</p>
      <button className="primary-button" onClick={onCreate}>新建文稿</button>
      <span className="shortcut-hint">⌘ N</span>
    </main>
  );
}
