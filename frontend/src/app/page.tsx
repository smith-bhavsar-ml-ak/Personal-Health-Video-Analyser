"use client";
import { useState, useEffect } from "react";
import { Activity, RefreshCw, Clock, TrendingUp } from "lucide-react";
import { api } from "@/lib/api";
import type { SessionSummary } from "@/lib/types";
import StatCard from "@/components/dashboard/StatCard";
import FormTrendChart from "@/components/dashboard/FormTrendChart";
import RecentSessions from "@/components/dashboard/RecentSessions";
import ExerciseBreakdown from "@/components/dashboard/ExerciseBreakdown";
import QuickUpload from "@/components/dashboard/QuickUpload";

export default function DashboardPage() {
  const [sessions, setSessions] = useState<SessionSummary[]>([]);

  useEffect(() => {
    api.listSessions().then(setSessions).catch(console.error);
  }, []);

  const totalReps     = sessions.reduce((a, s) => a + s.total_reps, 0);
  const avgScore      = sessions.length
    ? Math.round(sessions.reduce((a, s) => a + s.avg_form_score, 0) / sessions.length)
    : 0;
  const totalDuration = sessions.reduce((a, s) => a + (s.duration_s ?? 0), 0);
  const durationMin   = Math.round(totalDuration / 60);

  return (
    <div className="max-w-7xl mx-auto space-y-6 animate-fade-in-up">
      {/* Greeting */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-text-primary">Welcome back</h2>
          <p className="text-sm text-text-muted mt-0.5">
            {new Date().toLocaleDateString("en-US", { weekday: "long", month: "long", day: "numeric" })}
          </p>
        </div>
      </div>

      {/* Stat Cards */}
      <div className="grid grid-cols-4 gap-4">
        <StatCard label="Total Reps"     value={totalReps}       icon={RefreshCw}  accent="primary" />
        <StatCard label="Sessions"       value={sessions.length} icon={Activity}   accent="health"  />
        <StatCard label="Avg Form Score" value={`${avgScore}%`}  icon={TrendingUp} accent="primary" />
        <StatCard label="Total Active"   value={`${durationMin}m`} icon={Clock}   accent="health"  />
      </div>

      {/* Charts row */}
      <div className="grid grid-cols-3 gap-4">
        <div className="col-span-2">
          <FormTrendChart sessions={sessions} />
        </div>
        <ExerciseBreakdown sessions={sessions} />
      </div>

      {/* Bottom row */}
      <div className="grid grid-cols-3 gap-4">
        <div className="col-span-2">
          <RecentSessions sessions={sessions} />
        </div>
        <QuickUpload />
      </div>
    </div>
  );
}
