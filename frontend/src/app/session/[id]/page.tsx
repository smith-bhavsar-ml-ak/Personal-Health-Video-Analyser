import Link from "next/link";
import { ChevronLeft, TrendingUp, RefreshCw, Clock, Activity } from "lucide-react";
import { clsx } from "clsx";
import { api } from "@/lib/api";
import { EXERCISE_LABELS } from "@/lib/types";
import StatCard from "@/components/dashboard/StatCard";
import RepChart from "@/components/analyze/RepChart";
import PostureErrorList from "@/components/analyze/PostureErrorList";
import AIFeedbackPanel from "@/components/analyze/AIFeedbackPanel";

export const dynamic = "force-dynamic";

export default async function SessionPage({ params }: { params: { id: string } }) {
  const session = await api.getSession(params.id).catch(() => null);
  if (!session) return <p className="text-text-muted text-sm">Session not found.</p>;

  const totalReps   = session.exercise_sets.reduce((a, s) => a + s.rep_count, 0);
  const correctReps = session.exercise_sets.reduce((a, s) => a + s.correct_reps, 0);
  const avgScore    = session.exercise_sets.length
    ? session.exercise_sets.reduce((a, s) => a + s.form_score, 0) / session.exercise_sets.length
    : 0;

  return (
    <div className="max-w-5xl mx-auto space-y-6">
      {/* Breadcrumb */}
      <Link href="/history" className="flex items-center gap-1 text-xs text-text-muted hover:text-text-primary transition-colors cursor-pointer w-fit">
        <ChevronLeft className="w-3.5 h-3.5" /> Back to History
      </Link>

      {/* Session heading */}
      <div>
        <h2 className="text-xl font-bold text-text-primary">
          {new Date(session.created_at).toLocaleDateString("en-US", { weekday: "long", month: "long", day: "numeric", year: "numeric" })}
        </h2>
        <p className="text-xs text-text-muted mt-0.5">
          {new Date(session.created_at).toLocaleTimeString("en-US", { hour: "2-digit", minute: "2-digit" })}
        </p>
      </div>

      {/* Summary stats */}
      <div className="grid grid-cols-4 gap-4">
        <StatCard label="Total Reps"    value={totalReps}             icon={RefreshCw}  accent="primary" />
        <StatCard label="Correct Reps"  value={correctReps}           icon={Activity}   accent="health"  />
        <StatCard label="Avg Score"     value={`${avgScore.toFixed(0)}%`} icon={TrendingUp} accent="primary" />
        <StatCard label="Duration"      value={session.duration_s ? `${Math.round(session.duration_s / 60)}m ${session.duration_s % 60}s` : "—"} icon={Clock} accent="health" />
      </div>

      {/* Exercise detail cards */}
      <div className="space-y-4">
        {session.exercise_sets.map((set) => (
          <div key={set.id} className="bg-surface border border-white/[0.07] rounded-card overflow-hidden">
            <div className="flex items-center justify-between p-5 border-b border-white/5">
              <div className="flex items-center gap-3">
                <span className="text-xs font-medium bg-primary/10 text-primary px-2 py-0.5 rounded">
                  {EXERCISE_LABELS[set.exercise_type] ?? set.exercise_type}
                </span>
                <span className="text-sm text-text-secondary">{set.rep_count} reps · {set.correct_reps} correct · {set.duration_s}s</span>
              </div>
              <span className={clsx("text-lg font-bold", {
                "text-health":  set.form_score >= 80,
                "text-warning": set.form_score >= 60 && set.form_score < 80,
                "text-danger":  set.form_score < 60,
              })}>
                {set.form_score.toFixed(0)}%
              </span>
            </div>

            <div className="grid grid-cols-2 gap-0 divide-x divide-white/5">
              <div className="p-5">
                <p className="text-xs text-text-muted uppercase tracking-widest mb-3">Form per Rep</p>
                <RepChart repScores={Array(set.rep_count).fill(set.form_score)} />
              </div>
              <div className="p-5">
                <p className="text-xs text-text-muted uppercase tracking-widest mb-3">Posture Issues</p>
                <PostureErrorList errors={set.posture_errors} />
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* AI Feedback */}
      {session.ai_feedback && <AIFeedbackPanel feedback={session.ai_feedback.feedback_text} />}

      {/* Voice query log */}
      {session.voice_queries.length > 0 && (
        <div className="bg-surface border border-white/[0.07] rounded-card p-5 space-y-3">
          <p className="text-xs text-text-muted uppercase tracking-widest font-medium">AI Coach Queries</p>
          {session.voice_queries.map((q) => (
            <div key={q.id} className="flex flex-col gap-1 border-b border-white/5 pb-3 last:border-0 last:pb-0">
              <p className="text-xs text-primary">Q: {q.query_text}</p>
              <p className="text-xs text-text-secondary leading-relaxed">{q.response_text}</p>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
