"use client";
import { useState, useEffect, useCallback } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { ChevronRight, Video, Trash2, Clock, Target, AlertTriangle } from "lucide-react";
import { clsx } from "clsx";
import { api } from "@/lib/api";
import type { SessionSummary } from "@/lib/types";
import { EXERCISE_LABELS } from "@/lib/types";

function ScoreBar({ score }: { score: number }) {
  const color =
    score >= 80 ? "bg-health" : score >= 60 ? "bg-warning" : "bg-danger";
  const textColor =
    score >= 80 ? "text-health" : score >= 60 ? "text-warning" : "text-danger";
  return (
    <div className="flex items-center gap-2">
      <div className="flex-1 h-1.5 bg-surface-3 rounded-full overflow-hidden max-w-[64px]">
        <div className={clsx("h-full rounded-full transition-all duration-500", color)} style={{ width: `${score}%` }} />
      </div>
      <span className={clsx("text-xs font-semibold tabular-nums", textColor)}>{score.toFixed(0)}%</span>
    </div>
  );
}

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
      router.refresh();
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
            className="bg-surface-2 border border-white/[0.09] rounded-modal w-80 p-6 space-y-5 shadow-modal"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-start gap-3">
              <div className="w-9 h-9 rounded-lg bg-danger/10 border border-danger/20 flex items-center justify-center flex-shrink-0 mt-0.5">
                <AlertTriangle className="w-4 h-4 text-danger" />
              </div>
              <div>
                <p className="text-sm font-semibold text-text-primary">Delete session?</p>
                <p className="text-xs text-text-muted mt-1 leading-relaxed">This will permanently remove the session and all its data. This action cannot be undone.</p>
              </div>
            </div>
            <div className="flex gap-2 justify-end">
              <button
                onClick={() => setConfirmId(null)}
                className="text-sm px-4 py-2 rounded-lg border border-white/[0.09] text-text-secondary hover:bg-surface-3 transition-colors cursor-pointer"
              >
                Cancel
              </button>
              <button
                onClick={handleDelete}
                disabled={deleting}
                className="text-sm px-4 py-2 rounded-lg bg-danger hover:bg-danger/80 text-white font-medium transition-colors disabled:opacity-50 cursor-pointer"
              >
                {deleting ? "Deleting…" : "Delete"}
              </button>
            </div>
          </div>
        </div>
      )}

      <div className="max-w-4xl mx-auto space-y-5">
        <div className="flex items-center justify-between">
          <p className="text-sm text-text-muted">
            {sessions.length > 0
              ? `${sessions.length} session${sessions.length !== 1 ? "s" : ""} recorded`
              : "No sessions yet"}
          </p>
        </div>

        <div className="bg-surface border border-white/[0.07] rounded-card overflow-hidden">
          {sessions.length === 0 ? (
            <div className="flex flex-col items-center gap-4 py-16">
              <div className="w-14 h-14 rounded-xl bg-surface-2 border border-white/[0.07] flex items-center justify-center">
                <Video className="w-6 h-6 text-text-muted" />
              </div>
              <div className="text-center">
                <p className="text-sm font-semibold text-text-primary">No sessions yet</p>
                <p className="text-xs text-text-muted mt-1">Upload your first workout to get started</p>
              </div>
              <Link
                href="/analyze"
                className="text-sm bg-primary hover:bg-primary-dim text-white font-medium px-5 py-2.5 rounded-lg transition-colors cursor-pointer"
              >
                Analyze Workout
              </Link>
            </div>
          ) : (
            <>
              {/* Table header */}
              <div className="grid grid-cols-[1fr_1.5fr_80px_140px_120px_56px] gap-3 px-5 py-3 border-b border-white/[0.05] bg-surface-2/40">
                {["Date", "Exercises", "Reps", "Form Score", "Duration", ""].map((h, i) => (
                  <span key={i} className="text-[10px] text-text-muted uppercase tracking-widest font-medium">{h}</span>
                ))}
              </div>

              {/* Rows */}
              {sessions.map((s, i) => (
                <Link
                  key={s.id}
                  href={`/session/${s.id}`}
                  className={clsx(
                    "grid grid-cols-[1fr_1.5fr_80px_140px_120px_56px] gap-3 px-5 py-4 hover:bg-surface-2/60 transition-colors duration-150 cursor-pointer items-center group",
                    i < sessions.length - 1 && "border-b border-white/[0.04]"
                  )}
                >
                  <div>
                    <p className="text-sm text-text-primary font-medium">
                      {new Date(s.created_at).toLocaleDateString("en-US", { month: "short", day: "numeric" })}
                    </p>
                    <p className="text-[10px] text-text-muted mt-0.5">
                      {new Date(s.created_at).toLocaleDateString("en-US", { year: "numeric" })}
                    </p>
                  </div>

                  <div className="flex gap-1 flex-wrap">
                    {s.exercise_types.map((t) => (
                      <span key={t} className="text-[10px] bg-primary/10 text-primary px-1.5 py-0.5 rounded font-medium">
                        {EXERCISE_LABELS[t]}
                      </span>
                    ))}
                  </div>

                  <div className="flex items-center gap-1">
                    <Target className="w-3 h-3 text-text-muted" />
                    <span className="text-sm text-text-secondary font-mono">{s.total_reps}</span>
                  </div>

                  <ScoreBar score={s.avg_form_score} />

                  <div className="flex items-center gap-1.5 text-text-muted">
                    <Clock className="w-3 h-3" />
                    <span className="text-sm">
                      {s.duration_s ? `${Math.round(s.duration_s / 60)}m ${s.duration_s % 60}s` : "—"}
                    </span>
                  </div>

                  <div className="flex items-center gap-1 justify-end">
                    <button
                      onClick={(e) => { e.preventDefault(); e.stopPropagation(); setConfirmId(s.id); }}
                      className="w-7 h-7 rounded-lg flex items-center justify-center text-text-muted hover:text-danger hover:bg-danger/10 transition-colors cursor-pointer opacity-0 group-hover:opacity-100"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                    <ChevronRight className="w-4 h-4 text-text-muted/40 group-hover:text-text-muted transition-colors" />
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
