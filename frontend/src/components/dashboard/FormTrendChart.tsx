"use client";
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from "recharts";
import type { SessionSummary } from "@/lib/types";

interface Props {
  sessions: SessionSummary[];
}

export default function FormTrendChart({ sessions }: Props) {
  const data = sessions
    .slice()
    .reverse()
    .slice(-10)
    .map((s) => ({
      date: new Date(s.created_at).toLocaleDateString("en-US", { month: "short", day: "numeric" }),
      score: Math.round(s.avg_form_score),
    }));

  return (
    <div className="bg-surface border border-white/[0.07] rounded-card p-5">
      <h3 className="text-sm font-semibold text-text-primary mb-4">Form Score Trend</h3>
      <ResponsiveContainer width="100%" height={180}>
        <AreaChart data={data} margin={{ top: 4, right: 4, left: -20, bottom: 0 }}>
          <defs>
            <linearGradient id="scoreGrad" x1="0" y1="0" x2="0" y2="1">
              <stop offset="5%"  stopColor="#6366F1" stopOpacity={0.15} />
              <stop offset="95%" stopColor="#6366F1" stopOpacity={0.0} />
            </linearGradient>
          </defs>
          <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.04)" />
          <XAxis dataKey="date" tick={{ fill: "#475569", fontSize: 11 }} axisLine={false} tickLine={false} />
          <YAxis domain={[0, 100]} tick={{ fill: "#475569", fontSize: 11 }} axisLine={false} tickLine={false} />
          <Tooltip
            contentStyle={{ background: "#1C1C28", border: "1px solid rgba(255,255,255,0.1)", borderRadius: 8, color: "#F1F5F9", fontSize: 12 }}
            cursor={{ stroke: "rgba(255,255,255,0.08)" }}
          />
          <Area type="monotone" dataKey="score" stroke="#6366F1" strokeWidth={2} fill="url(#scoreGrad)" dot={false} />
        </AreaChart>
      </ResponsiveContainer>
    </div>
  );
}
