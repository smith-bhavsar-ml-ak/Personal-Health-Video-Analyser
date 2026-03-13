import { clsx } from "clsx";
import type { LucideIcon } from "lucide-react";
import { TrendingUp, TrendingDown } from "lucide-react";

interface StatCardProps {
  label: string;
  value: string | number;
  delta?: string;
  deltaPositive?: boolean;
  icon: LucideIcon;
  accent?: "primary" | "health" | "warning";
}

const ACCENT = {
  primary: { text: "text-primary", bg: "bg-primary/10", bar: "bg-primary" },
  health:  { text: "text-health",  bg: "bg-health/10",  bar: "bg-health"  },
  warning: { text: "text-warning", bg: "bg-warning/10", bar: "bg-warning" },
};

export default function StatCard({ label, value, delta, deltaPositive, icon: Icon, accent = "primary" }: StatCardProps) {
  const a = ACCENT[accent];
  return (
    <div className="relative bg-surface border border-white/[0.07] rounded-card p-5 flex flex-col gap-3 hover:bg-surface-2 hover:border-white/[0.12] transition-all duration-150 cursor-default overflow-hidden">
      {/* Left accent bar */}
      <div className={clsx("absolute left-0 top-4 bottom-4 w-[3px] rounded-r-full", a.bar)} />

      <div className="flex items-center justify-between pl-2">
        <span className="text-xs text-text-muted uppercase tracking-widest font-medium">{label}</span>
        <div className={clsx("w-8 h-8 rounded-lg flex items-center justify-center", a.bg)}>
          <Icon className={clsx("w-4 h-4", a.text)} />
        </div>
      </div>

      <div className="flex items-end justify-between pl-2">
        <span className={clsx("text-3xl font-bold tracking-tight", a.text)}>{value}</span>
        {delta && (
          <span className={clsx(
            "flex items-center gap-0.5 text-xs font-medium mb-0.5",
            deltaPositive ? "text-health" : "text-danger"
          )}>
            {deltaPositive
              ? <TrendingUp className="w-3 h-3" />
              : <TrendingDown className="w-3 h-3" />}
            {delta}
          </span>
        )}
      </div>
    </div>
  );
}
