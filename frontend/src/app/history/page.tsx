import Link from "next/link";
import { ChevronRight, Video } from "lucide-react";
import { clsx } from "clsx";
import { api } from "@/lib/api";
import { EXERCISE_LABELS } from "@/lib/types";

export const dynamic = "force-dynamic";

export default async function HistoryPage() {
  let sessions = [];
  try { sessions = await api.listSessions(); } catch (e) { console.error("Failed to load sessions:", e); }

  return (
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
            {/* Table header */}
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
                <div className="flex items-center justify-between">
                  <span className="text-sm text-text-muted">{s.duration_s ? `${Math.round(s.duration_s / 60)}m ${s.duration_s % 60}s` : "—"}</span>
                  <ChevronRight className="w-4 h-4 text-text-muted" />
                </div>
              </Link>
            ))}
          </>
        )}
      </div>
    </div>
  );
}
