import Link from "next/link";
import { ChevronRight } from "lucide-react";
import { clsx } from "clsx";
import type { SessionSummary } from "@/lib/types";
import { EXERCISE_LABELS } from "@/lib/types";

interface Props { sessions: SessionSummary[] }

function ScoreBadge({ score }: { score: number }) {
  return (
    <span className={clsx("text-xs font-medium px-2 py-0.5 rounded", {
      "bg-health/10 text-health":   score >= 80,
      "bg-warning/10 text-warning": score >= 60 && score < 80,
      "bg-danger/10 text-danger":   score < 60,
    })}>
      {score.toFixed(0)}%
    </span>
  );
}

export default function RecentSessions({ sessions }: Props) {
  const recent = sessions.slice(0, 6);

  return (
    <div className="bg-surface border border-white/[0.07] rounded-card p-5">
      <div className="flex items-center justify-between mb-4">
        <h3 className="text-sm font-semibold text-text-primary">Recent Sessions</h3>
        <Link href="/history" className="text-xs text-text-muted hover:text-primary transition-colors cursor-pointer">
          View all
        </Link>
      </div>

      {recent.length === 0 ? (
        <p className="text-sm text-text-muted text-center py-6">No sessions yet</p>
      ) : (
        <div className="flex flex-col">
          {recent.map((s, i) => (
            <Link
              key={s.id}
              href={`/session/${s.id}`}
              className={clsx(
                "flex items-center justify-between py-3 cursor-pointer hover:bg-surface-2 -mx-5 px-5 transition-colors duration-150",
                i < recent.length - 1 && "border-b border-white/5"
              )}
            >
              <div className="flex flex-col gap-1">
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
              </div>
              <div className="flex items-center gap-3">
                <ScoreBadge score={s.avg_form_score} />
                <ChevronRight className="w-4 h-4 text-text-muted" />
              </div>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
