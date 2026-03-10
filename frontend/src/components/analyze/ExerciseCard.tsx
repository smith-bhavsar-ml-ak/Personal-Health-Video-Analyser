"use client";
import { useState } from "react";
import { ChevronDown, ChevronUp } from "lucide-react";
import { clsx } from "clsx";
import type { ExerciseSet } from "@/lib/types";
import { EXERCISE_LABELS } from "@/lib/types";
import RepChart from "./RepChart";
import PostureErrorList from "./PostureErrorList";

interface Props { set: ExerciseSet; delay?: number }

export default function ExerciseCard({ set, delay = 0 }: Props) {
  const [expanded, setExpanded] = useState(true);
  const score = set.form_score;

  return (
    <div
      className="bg-surface border border-white/[0.07] rounded-card overflow-hidden animate-fade-in-up"
      style={{ animationDelay: `${delay}ms` }}
    >
      {/* Header */}
      <button
        onClick={() => setExpanded((v) => !v)}
        className="w-full flex items-center justify-between p-5 cursor-pointer hover:bg-surface-2 transition-colors"
      >
        <div className="flex items-center gap-3">
          <span className="text-xs font-medium bg-primary/10 text-primary px-2 py-0.5 rounded">
            {EXERCISE_LABELS[set.exercise_type] ?? set.exercise_type}
          </span>
          <span className="text-sm font-semibold text-text-primary">{set.rep_count} reps</span>
          <span className="text-xs text-text-muted">{set.correct_reps} correct · {set.duration_s}s</span>
        </div>
        <div className="flex items-center gap-3">
          <span className={clsx("text-sm font-bold", {
            "text-health":   score >= 80,
            "text-warning":  score >= 60 && score < 80,
            "text-danger":   score < 60,
          })}>
            {score.toFixed(0)}%
          </span>
          {expanded ? <ChevronUp className="w-4 h-4 text-text-muted" /> : <ChevronDown className="w-4 h-4 text-text-muted" />}
        </div>
      </button>

      {/* Expanded content */}
      {expanded && (
        <div className="px-5 pb-5 flex flex-col gap-4 border-t border-white/5">
          <div className="pt-4">
            <p className="text-xs text-text-muted uppercase tracking-widest mb-3">Form per Rep</p>
            <RepChart repScores={set.posture_errors.length > 0 ? Array(set.rep_count).fill(set.form_score) : []} />
          </div>
          <div>
            <p className="text-xs text-text-muted uppercase tracking-widest mb-3">Posture Issues</p>
            <PostureErrorList errors={set.posture_errors} />
          </div>
        </div>
      )}
    </div>
  );
}
