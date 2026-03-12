"use client";
import { useState, useEffect, useCallback } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { ChevronRight, Video, Trash2 } from "lucide-react";
import { clsx } from "clsx";
import { api } from "@/lib/api";
import type { SessionSummary } from "@/lib/types";
import { EXERCISE_LABELS } from "@/lib/types";

export default function HistoryPage() {
  const router = useRouter();
  const [sessions, setSessions]   = useState<SessionSummary[]>([]);
  const [deleting, setDeleting]   = useState(false);
  const [confirmId, setConfirmId] = useState<string | null>(null);

  const load = useCallback(async () => {
    try { setSessions(await api.listSessions()); } catch (e) { console.error(e); }
  }, []);

  useEffect(() => { load(); }, [load]);

  const handleDelete = async () => {
    if (!confirmId) return;
    setDeleting(true);
    try {
      await api.deleteSession(confirmId);
      setSessions((prev) => prev.filter((s) => s.id !== confirmId));
      router.refresh(); // bust router cache so dashboard also sees change
    } catch (err) {
      console.error(err);
    } finally {
      setDeleting(false);
      setConfirmId(null);
    }
  };

  return (
    <>
      {/* Confirmation modal */}
      {confirmId && (
        <div
          className="fixed inset-0 bg-black/60 flex items-center justify-center z-50"
          onClick={() => setConfirmId(null)}
        >
          <div
            className="bg-surface-2 border border-white/10 rounded-2xl p-6 w-80 space-y-4"
            onClick={(e) => e.stopPropagation()}
          >
            <div>
              <p className="text-sm font-semibold text-text-primary">Delete session?</p>
              <p className="text-xs text-text-muted mt-1">This action cannot be undone.</p>
            </div>
            <div className="flex gap-2 justify-end">
              <button
                onClick={() => setConfirmId(null)}
                className="text-sm px-4 py-2 rounded-lg border border-white/10 text-text-secondary hover:bg-surface-3 transition-colors cursor-pointer"
              >
                Cancel
              </button>
              <button
                onClick={handleDelete}
                disabled={deleting}
                className="text-sm px-4 py-2 rounded-lg bg-danger hover:bg-danger/80 text-white transition-colors disabled:opacity-50 cursor-pointer"
              >
                {deleting ? "Deleting…" : "Delete"}
              </button>
            </div>
          </div>
        </div>
      )}

      <div className="max-w-4xl mx-auto space-y-5">
        <div className="flex items-center justify-between">
          <p className="text-sm text-text-muted">{sessions.length} session{sessions.length !== 1 ? "s" : ""} total</p>
        </div>

        <div className="bg-surface border border-white/[0.07] rounded-card overflow-hidden">
          {sessions.length === 0 ? (
            <div className="flex flex-col items-center gap-4 py-16">
              <div className="w-12 h-12 rounded-xl bg-surface-2 flex items-center justify-center">
                <Video className="w-6 h-6 text-text-muted" />
              </div>
              <div className="text-center">
                <p className="text-sm font-medium text-text-primary">No sessions yet</p>
                <p className="text-xs text-text-muted mt-1">Upload your first workout to get started</p>
              </div>
              <Link href="/analyze" className="text-sm bg-primary hover:bg-primary-dim text-white px-4 py-2 rounded-lg transition-colors cursor-pointer">
                Analyze Workout
              </Link>
            </div>
          ) : (
            <>
              {/* Table header — 5 cols matching original */}
              <div className="grid grid-cols-5 gap-4 px-5 py-3 border-b border-white/5">
                {["Date", "Exercises", "Reps", "Score", "Duration"].map((h) => (
                  <span key={h} className="text-xs text-text-muted uppercase tracking-widest font-medium">{h}</span>
                ))}
              </div>

              {/* Rows */}
              {sessions.map((s, i) => (
                <Link
                  key={s.id}
                  href={`/session/${s.id}`}
                  className={clsx(
                    "grid grid-cols-5 gap-4 px-5 py-4 hover:bg-surface-2 transition-colors duration-150 cursor-pointer items-center",
                    i < sessions.length - 1 && "border-b border-white/5"
                  )}
                >
                  <span className="text-sm text-text-primary">
                    {new Date(s.created_at).toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" })}
                  </span>
                  <div className="flex gap-1 flex-wrap">
                    {s.exercise_types.map((t) => (
                      <span key={t} className="text-xs bg-primary/10 text-primary/80 px-1.5 py-0.5 rounded">
                        {EXERCISE_LABELS[t]}
                      </span>
                    ))}
                  </div>
                  <span className="text-sm text-text-secondary font-mono">{s.total_reps}</span>
                  <span className={clsx("text-sm font-medium", {
                    "text-health":   s.avg_form_score >= 80,
                    "text-warning":  s.avg_form_score >= 60 && s.avg_form_score < 80,
                    "text-danger":   s.avg_form_score < 60,
                  })}>
                    {s.avg_form_score.toFixed(0)}%
                  </span>
                  {/* Duration col: text + delete + chevron */}
                  <div className="flex items-center justify-between">
                    <span className="text-sm text-text-muted">
                      {s.duration_s ? `${Math.round(s.duration_s / 60)}m ${s.duration_s % 60}s` : "—"}
                    </span>
                    <div className="flex items-center gap-1">
                      <button
                        onClick={(e) => { e.preventDefault(); e.stopPropagation(); setConfirmId(s.id); }}
                        className="w-7 h-7 rounded-lg flex items-center justify-center hover:bg-danger/10 text-text-muted hover:text-danger transition-colors cursor-pointer"
                      >
                        <Trash2 className="w-3.5 h-3.5" />
                      </button>
                      <ChevronRight className="w-4 h-4 text-text-muted" />
                    </div>
                  </div>
                </Link>
              ))}
            </>
          )}
        </div>
      </div>
    </>
  );
}
