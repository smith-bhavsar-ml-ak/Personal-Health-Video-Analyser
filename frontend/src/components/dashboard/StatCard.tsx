import { clsx } from "clsx";
import type { LucideIcon } from "lucide-react";

interface StatCardProps {
  label: string;
  value: string | number;
  delta?: string;
  deltaPositive?: boolean;
  icon: LucideIcon;
  accent?: "primary" | "health" | "warning";
}

const ACCENT_COLORS = {
  primary: "text-primary",
  health:  "text-health",
  warning: "text-warning",
};

export default function StatCard({ label, value, delta, deltaPositive, icon: Icon, accent = "primary" }: StatCardProps) {
  return (
    <div className="bg-surface border border-white/[0.07] rounded-card p-5 flex flex-col gap-3 hover:bg-surface-2 hover:border-white/[0.12] transition-all duration-150 cursor-default">
      <div className="flex items-center justify-between">
        <span className="text-xs text-text-muted uppercase tracking-widest font-medium">{label}</span>
        <div className={clsx("w-8 h-8 rounded-lg flex items-center justify-center", {
          "bg-primary/10": accent === "primary",
          "bg-health/10":  accent === "health",
          "bg-warning/10": accent === "warning",
        })}>
          <Icon className={clsx("w-4 h-4", ACCENT_COLORS[accent])} />
        </div>
      </div>
      <div className="flex items-end justify-between">
        <span className={clsx("text-4xl font-bold", ACCENT_COLORS[accent])}>{value}</span>
        {delta && (
          <span className={clsx("text-xs font-medium mb-1", deltaPositive ? "text-health" : "text-danger")}>
            {deltaPositive ? "↑" : "↓"} {delta}
          </span>
        )}
      </div>
    </div>
  );
}
