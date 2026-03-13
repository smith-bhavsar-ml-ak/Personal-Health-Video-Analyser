import type { SessionSummary } from "@/lib/types";
import { EXERCISE_LABELS, EXERCISE_COLORS } from "@/lib/types";

interface Props { sessions: SessionSummary[] }

export default function ExerciseBreakdown({ sessions }: Props) {
  const counts: Record<string, number> = {};
  sessions.forEach((s) => s.exercise_types.forEach((t) => {
    counts[t] = (counts[t] ?? 0) + 1;
  }));
  const total = Object.values(counts).reduce((a, b) => a + b, 0) || 1;

  const data = Object.entries(counts)
    .map(([type, count]) => ({
      name:  EXERCISE_LABELS[type as keyof typeof EXERCISE_LABELS] ?? type,
      value: Math.round((count / total) * 100),
      count,
      fill:  EXERCISE_COLORS[type as keyof typeof EXERCISE_COLORS] ?? "#6366F1",
    }))
    .sort((a, b) => b.value - a.value);

  if (data.length === 0) {
    return (
      <div className="bg-surface border border-white/[0.07] rounded-card p-5 flex flex-col items-center justify-center gap-2 min-h-[140px]">
        <p className="text-sm text-text-muted">No data yet</p>
        <p className="text-xs text-text-muted/60">Analyze your first workout</p>
      </div>
    );
  }

  return (
    <div className="bg-surface border border-white/[0.07] rounded-card p-5">
      <div className="flex items-center justify-between mb-4">
        <h3 className="text-sm font-semibold text-text-primary">Exercise Mix</h3>
        <span className="text-xs text-text-muted">{sessions.length} sessions</span>
      </div>

      <div className="flex flex-col gap-3">
        {data.map((item) => (
          <div key={item.name}>
            <div className="flex items-center justify-between mb-1.5">
              <div className="flex items-center gap-2">
                <span className="w-1.5 h-1.5 rounded-full flex-shrink-0" style={{ background: item.fill }} />
                <span className="text-xs text-text-secondary">{item.name}</span>
              </div>
              <div className="flex items-center gap-2">
                <span className="text-xs text-text-muted">{item.count}×</span>
                <span className="text-xs font-medium text-text-primary w-8 text-right">{item.value}%</span>
              </div>
            </div>
            <div className="h-1.5 bg-surface-3 rounded-full overflow-hidden">
              <div
                className="h-full rounded-full transition-all duration-500"
                style={{ width: `${item.value}%`, background: item.fill }}
              />
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
