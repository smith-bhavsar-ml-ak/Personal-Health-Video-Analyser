"use client";
import { RadialBarChart, RadialBar, Legend, ResponsiveContainer, Tooltip } from "recharts";
import type { SessionSummary } from "@/lib/types";
import { EXERCISE_LABELS, EXERCISE_COLORS } from "@/lib/types";

interface Props { sessions: SessionSummary[] }

export default function ExerciseBreakdown({ sessions }: Props) {
  const counts: Record<string, number> = {};
  sessions.forEach((s) => s.exercise_types.forEach((t) => { counts[t] = (counts[t] ?? 0) + 1; }));
  const total = Object.values(counts).reduce((a, b) => a + b, 0) || 1;

  const data = Object.entries(counts).map(([type, count]) => ({
    name: EXERCISE_LABELS[type as keyof typeof EXERCISE_LABELS] ?? type,
    value: Math.round((count / total) * 100),
    fill: EXERCISE_COLORS[type as keyof typeof EXERCISE_COLORS] ?? "#6366F1",
  }));

  if (data.length === 0) {
    return (
      <div className="bg-surface border border-white/[0.07] rounded-card p-5 flex items-center justify-center">
        <p className="text-sm text-text-muted">No data yet</p>
      </div>
    );
  }

  return (
    <div className="bg-surface border border-white/[0.07] rounded-card p-5">
      <h3 className="text-sm font-semibold text-text-primary mb-4">Exercise Breakdown</h3>
      <ResponsiveContainer width="100%" height={180}>
        <RadialBarChart cx="50%" cy="50%" innerRadius="30%" outerRadius="90%" data={data} startAngle={180} endAngle={0}>
          <RadialBar dataKey="value" cornerRadius={4} />
          <Tooltip
            contentStyle={{ background: "#1C1C28", border: "1px solid rgba(255,255,255,0.1)", borderRadius: 8, color: "#F1F5F9", fontSize: 12 }}
            formatter={(val: number) => [`${val}%`, ""]}
          />
          <Legend iconSize={8} wrapperStyle={{ fontSize: 11, color: "#94A3B8", paddingTop: 8 }} />
        </RadialBarChart>
      </ResponsiveContainer>
    </div>
  );
}
