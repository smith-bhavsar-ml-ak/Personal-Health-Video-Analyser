import Link from "next/link";
import { ChevronLeft, TrendingUp, RefreshCw, Clock, Activity, MessageSquare, Target, CheckCircle2 } from "lucide-react";
import { clsx } from "clsx";
import { api } from "@/lib/api";
import { EXERCISE_LABELS } from "@/lib/types";
import StatCard from "@/components/dashboard/StatCard";
import RepChart from "@/components/analyze/RepChart";
import PostureErrorList from "@/components/analyze/PostureErrorList";
import AIFeedbackPanel from "@/components/analyze/AIFeedbackPanel";

export const dynamic = "force-dynamic";

function ScoreRing({ score }: { score: number }) {
  const r = 18;
  const cx = 22;
  const circumference = 2 * Math.PI * r;
  const dash = (score / 100) * circumference;
  const color = score >= 80 ? "#10B981" : score >= 60 ? "#F59E0B" : "#EF4444";
  return (
    <svg width={44} height={44} className="flex-shrink-0 -rotate-90">
      <circle cx={cx} cy={cx} r={r} fill="none" stroke="rgba(255,255,255,0.06)" strokeWidth={3} />
      <circle
        cx={cx} cy={cx} r={r}
        fill="none"
        stroke={color}
        strokeWidth={3}
        strokeLinecap="round"
        strokeDasharray={`${dash} ${circumference - dash}`}
      />
      <text
        x={cx} y={cx}
        textAnchor="middle"
        dominantBaseline="central"
        style={{ rotate: "90deg", transformOrigin: `${cx}px ${cx}px`, fill: color, fontSize: 9, fontWeight: 700, fontFamily: "inherit" }}
      >
        {score.toFixed(0)}%
      </text>
    </svg>
  );
}

export default async function SessionPage({ params }: { params: { id: string } }) {
  const session = await api.getSession(params.id).catch(() => null);
  if (!session) return (
    <div className="max-w-5xl mx-auto pt-12 text-center">
      <p className="text-sm text-text-muted">Session not found.</p>
      <Link href="/history" className="mt-4 inline-flex items-center gap-1 text-xs text-primary hover:text-primary/80 transition-colors cursor-pointer">
        <ChevronLeft className="w-3.5 h-3.5" /> Back to History
      </Link>
    </div>
  );

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
      <div className="flex items-start justify-between">
        <div>
          <h2 className="text-xl font-bold text-text-primary">
            {new Date(session.created_at).toLocaleDateString("en-US", { weekday: "long", month: "long", day: "numeric", year: "numeric" })}
          </h2>
          <p className="text-xs text-text-muted mt-0.5">
            {new Date(session.created_at).toLocaleTimeString("en-US", { hour: "2-digit", minute: "2-digit" })}
            {session.exercise_sets.length > 0 && (
              <span className="ml-2 text-primary/60">· {session.exercise_sets.length} exercise set{session.exercise_sets.length !== 1 ? "s" : ""}</span>
            )}
          </p>
        </div>
      </div>

      {/* Summary stats */}
      <div className="grid grid-cols-4 gap-4">
        <StatCard label="Total Reps"   value={totalReps}                         icon={RefreshCw}  accent="primary" />
        <StatCard label="Correct Reps" value={correctReps}                       icon={Activity}   accent="health"  />
        <StatCard label="Avg Score"    value={`${avgScore.toFixed(0)}%`}         icon={TrendingUp} accent="primary" />
        <StatCard label="Duration"     value={session.duration_s ? `${Math.round(session.duration_s / 60)}m ${session.duration_s % 60}s` : "—"} icon={Clock} accent="health" />
      </div>

      {/* Exercise sets */}
      <div className="space-y-4">
        {session.exercise_sets.map((set) => (
          <div key={set.id} className="bg-surface border border-white/[0.07] rounded-card overflow-hidden">
            {/* Set header */}
            <div className="flex items-center justify-between px-5 py-4 border-b border-white/[0.05]">
              <div className="flex items-center gap-3">
                <span className="text-xs font-semibold bg-primary/10 text-primary px-2.5 py-1 rounded-md">
                  {EXERCISE_LABELS[set.exercise_type] ?? set.exercise_type}
                </span>
                <div className="flex items-center gap-2 text-xs text-text-muted">
                  <span className="flex items-center gap-1">
                    <Target className="w-3 h-3" />
                    {set.rep_count} reps
                  </span>
                  <span className="text-white/20">·</span>
                  <span className="flex items-center gap-1">
                    <CheckCircle2 className="w-3 h-3 text-health/60" />
                    {set.correct_reps} correct
                  </span>
                  <span className="text-white/20">·</span>
                  <span>{set.duration_s}s</span>
                </div>
              </div>
              <ScoreRing score={set.form_score} />
            </div>

            {/* Set body */}
            <div className="grid grid-cols-2 divide-x divide-white/[0.05]">
              <div className="p-5">
                <p className="text-[10px] text-text-muted uppercase tracking-widest font-medium mb-3">Form per Rep</p>
                <RepChart repScores={Array(set.rep_count).fill(set.form_score)} />
              </div>
              <div className="p-5">
                <p className="text-[10px] text-text-muted uppercase tracking-widest font-medium mb-3">Posture Issues</p>
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
        <div className="bg-surface border border-white/[0.07] rounded-card overflow-hidden">
          <div className="flex items-center gap-2 px-5 py-4 border-b border-white/[0.05]">
            <div className="w-6 h-6 rounded-md bg-primary/10 flex items-center justify-center">
              <MessageSquare className="w-3.5 h-3.5 text-primary" />
            </div>
            <p className="text-xs font-medium text-text-primary uppercase tracking-widest">AI Coach Queries</p>
            <span className="ml-auto text-xs text-text-muted bg-surface-3 px-2 py-0.5 rounded-full">
              {session.voice_queries.length}
            </span>
          </div>
          <div className="divide-y divide-white/[0.04]">
            {session.voice_queries.map((q) => (
              <div key={q.id} className="px-5 py-4 space-y-2">
                <p className="text-xs font-medium text-primary flex items-start gap-2">
                  <span className="text-primary/40 font-bold mt-0.5">Q</span>
                  {q.query_text}
                </p>
                <p className="text-xs text-text-secondary leading-relaxed pl-4">{q.response_text}</p>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
