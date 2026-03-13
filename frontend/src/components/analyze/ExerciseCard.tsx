"use client";
import { useState } from "react";
import { ChevronDown, ChevronUp, CheckCircle2, Target } from "lucide-react";
import { clsx } from "clsx";
import type { ExerciseSet } from "@/lib/types";
import { EXERCISE_LABELS } from "@/lib/types";
import RepChart from "./RepChart";
import PostureErrorList from "./PostureErrorList";

interface Props { set: ExerciseSet; delay?: number }

function ScoreRing({ score }: { score: number }) {
  const r  = 18;
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
        style={{ transition: "stroke-dasharray 0.6s ease" }}
      />
      <text
        x={cx} y={cx}
        textAnchor="middle"
        dominantBaseline="central"
        className="rotate-90"
        style={{ rotate: "90deg", transformOrigin: `${cx}px ${cx}px`, fill: color, fontSize: 9, fontWeight: 700, fontFamily: "inherit" }}
      >
        {score.toFixed(0)}%
      </text>
    </svg>
  );
}

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
        className="w-full flex items-center justify-between px-5 py-4 cursor-pointer hover:bg-surface-2 transition-colors duration-150"
      >
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
        <div className="flex items-center gap-3">
          <ScoreRing score={score} />
          {expanded
            ? <ChevronUp   className="w-4 h-4 text-text-muted" />
            : <ChevronDown className="w-4 h-4 text-text-muted" />}
        </div>
      </button>

      {/* Body */}
      {expanded && (
        <div className="border-t border-white/[0.05]">
          <div className="grid grid-cols-2 divide-x divide-white/[0.05]">
            <div className="p-5">
              <p className="text-[10px] text-text-muted uppercase tracking-widest font-medium mb-3">Form per Rep</p>
              <RepChart repScores={set.posture_errors.length > 0 ? Array(set.rep_count).fill(set.form_score) : []} />
            </div>
            <div className="p-5">
              <p className="text-[10px] text-text-muted uppercase tracking-widest font-medium mb-3">Posture Issues</p>
              <PostureErrorList errors={set.posture_errors} />
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
