"use client";
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, ReferenceLine } from "recharts";
import type { SessionSummary } from "@/lib/types";

interface Props { sessions: SessionSummary[] }

export default function FormTrendChart({ sessions }: Props) {
  const data = sessions
    .slice()
    .reverse()
    .slice(-10)
    .map((s) => ({
      date:  new Date(s.created_at).toLocaleDateString("en-US", { month: "short", day: "numeric" }),
      score: Math.round(s.avg_form_score),
    }));

  const avg = data.length
    ? Math.round(data.reduce((a, d) => a + d.score, 0) / data.length)
    : null;

  return (
    <div className="bg-surface border border-white/[0.07] rounded-card p-5">
      <div className="flex items-center justify-between mb-4">
        <div>
          <h3 className="text-sm font-semibold text-text-primary">Form Score Trend</h3>
          {avg !== null && (
            <p className="text-xs text-text-muted mt-0.5">
              Average: <span className={avg >= 80 ? "text-health" : avg >= 60 ? "text-warning" : "text-danger"}>{avg}%</span>
            </p>
          )}
        </div>
        <span className="text-xs text-text-muted">{data.length} sessions</span>
      </div>

      {data.length === 0 ? (
        <div className="h-[180px] flex items-center justify-center">
          <p className="text-sm text-text-muted">No sessions to display</p>
        </div>
      ) : (
        <ResponsiveContainer width="100%" height={180}>
          <AreaChart data={data} margin={{ top: 8, right: 4, left: -20, bottom: 0 }}>
            <defs>
              <linearGradient id="scoreGrad" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%"  stopColor="#6366F1" stopOpacity={0.18} />
                <stop offset="95%" stopColor="#6366F1" stopOpacity={0}    />
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.04)" vertical={false} />
            <XAxis dataKey="date" tick={{ fill: "#475569", fontSize: 11 }} axisLine={false} tickLine={false} />
            <YAxis domain={[0, 100]} tick={{ fill: "#475569", fontSize: 11 }} axisLine={false} tickLine={false} />
            <ReferenceLine y={80} stroke="rgba(16,185,129,0.15)" strokeDasharray="4 4" />
            <Tooltip
              contentStyle={{ background: "#1C1C28", border: "1px solid rgba(255,255,255,0.1)", borderRadius: 8, color: "#F1F5F9", fontSize: 12 }}
              cursor={{ stroke: "rgba(255,255,255,0.08)" }}
              formatter={(val: number) => [`${val}%`, "Form Score"]}
            />
            <Area
              type="monotone"
              dataKey="score"
              stroke="#6366F1"
              strokeWidth={2}
              fill="url(#scoreGrad)"
              dot={{ fill: "#6366F1", r: 3, strokeWidth: 0 }}
              activeDot={{ fill: "#6366F1", r: 4, strokeWidth: 0 }}
            />
          </AreaChart>
        </ResponsiveContainer>
      )}
    </div>
  );
}
