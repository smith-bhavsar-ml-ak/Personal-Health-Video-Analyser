"use client";
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ReferenceLine, Cell, ResponsiveContainer } from "recharts";

interface Props { repScores: number[] }

export default function RepChart({ repScores }: Props) {
  if (!repScores.length) return null;

  const data = repScores.map((score, i) => ({ rep: i + 1, score: Math.round(score) }));

  return (
    <ResponsiveContainer width="100%" height={160}>
      <BarChart data={data} margin={{ top: 4, right: 4, left: -20, bottom: 0 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.04)" />
        <XAxis dataKey="rep" label={{ value: "Rep", position: "insideBottom", offset: -2, fill: "#475569", fontSize: 11 }} tick={{ fill: "#475569", fontSize: 11 }} axisLine={false} tickLine={false} />
        <YAxis domain={[0, 100]} tick={{ fill: "#475569", fontSize: 11 }} axisLine={false} tickLine={false} />
        <ReferenceLine y={80} stroke="rgba(255,255,255,0.15)" strokeDasharray="4 4" label={{ value: "Good", position: "right", fill: "#475569", fontSize: 10 }} />
        <Tooltip
          contentStyle={{ background: "#1C1C28", border: "1px solid rgba(255,255,255,0.1)", borderRadius: 8, color: "#F1F5F9", fontSize: 12 }}
          formatter={(val: number) => [`${val}%`, "Form Score"]}
        />
        <Bar dataKey="score" radius={[3, 3, 0, 0]}>
          {data.map((entry, i) => (
            <Cell
              key={i}
              fill={entry.score >= 80 ? "#10B981" : entry.score >= 60 ? "#F59E0B" : "#EF4444"}
            />
          ))}
        </Bar>
      </BarChart>
    </ResponsiveContainer>
  );
}
