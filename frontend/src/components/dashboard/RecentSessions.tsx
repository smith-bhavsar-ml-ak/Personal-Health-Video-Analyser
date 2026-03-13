import Link from "next/link";
import { ChevronRight, Clock } from "lucide-react";
import { clsx } from "clsx";
import type { SessionSummary } from "@/lib/types";
import { EXERCISE_LABELS } from "@/lib/types";

interface Props { sessions: SessionSummary[] }

function ScoreBar({ score }: { score: number }) {
  const color = score >= 80 ? "bg-health" : score >= 60 ? "bg-warning" : "bg-danger";
  const textColor = score >= 80 ? "text-health" : score >= 60 ? "text-warning" : "text-danger";
  return (
    <div className="flex items-center gap-2">
      <div className="w-16 h-1.5 bg-surface-3 rounded-full overflow-hidden">
        <div className={clsx("h-full rounded-full transition-all", color)} style={{ width: `${score}%` }} />
      </div>
      <span className={clsx("text-xs font-semibold tabular-nums w-8 text-right", textColor)}>
        {score.toFixed(0)}%
      </span>
    </div>
  );
}

function timeAgo(dateStr: string): string {
  const diff = Date.now() - new Date(dateStr).getTime();
  const days = Math.floor(diff / 86_400_000);
  if (days === 0) return "Today";
  if (days === 1) return "Yesterday";
  if (days < 7)  return `${days}d ago`;
  if (days < 30) return `${Math.floor(days / 7)}w ago`;
  return new Date(dateStr).toLocaleDateString("en-US", { month: "short", day: "numeric" });
}

export default function RecentSessions({ sessions }: Props) {
  const recent = sessions.slice(0, 6);

  return (
    <div className="bg-surface border border-white/[0.07] rounded-card p-5">
      <div className="flex items-center justify-between mb-1">
        <h3 className="text-sm font-semibold text-text-primary">Recent Sessions</h3>
        <Link href="/history" className="text-xs text-text-muted hover:text-primary transition-colors duration-150 cursor-pointer">
          View all
        </Link>
      </div>

      {recent.length === 0 ? (
        <div className="py-10 flex flex-col items-center gap-2">
          <Clock className="w-8 h-8 text-text-muted/40" />
          <p className="text-sm text-text-muted">No sessions yet</p>
        </div>
      ) : (
        <div className="flex flex-col mt-2">
          {recent.map((s, i) => (
            <Link
              key={s.id}
              href={`/session/${s.id}`}
              className={clsx(
                "flex items-center justify-between py-3 -mx-5 px-5 hover:bg-surface-2 transition-colors duration-150 cursor-pointer",
                i < recent.length - 1 && "border-b border-white/[0.05]"
              )}
            >
              <div className="flex flex-col gap-1 min-w-0">
                <div className="flex items-center gap-2">
                  <span className="text-sm text-text-primary font-medium">{timeAgo(s.created_at)}</span>
                  <span className="text-xs text-text-muted">{s.total_reps} reps</span>
                </div>
                <div className="flex gap-1 flex-wrap">
                  {s.exercise_types.map((t) => (
                    <span key={t} className="text-xs bg-primary/10 text-primary/80 px-1.5 py-0.5 rounded">
                      {EXERCISE_LABELS[t]}
                    </span>
                  ))}
                </div>
              </div>
              <div className="flex items-center gap-3 flex-shrink-0">
                <ScoreBar score={s.avg_form_score} />
                <ChevronRight className="w-4 h-4 text-text-muted" />
              </div>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
