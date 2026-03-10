"use client";
import { usePathname } from "next/navigation";
import { User } from "lucide-react";

const TITLES: Record<string, string> = {
  "/":          "Dashboard",
  "/analyze":   "Analyze Workout",
  "/history":   "Workout History",
  "/assistant": "AI Coach",
};

export default function Header() {
  const pathname = usePathname();
  const title = TITLES[pathname] ?? "HealthVision AI";

  return (
    <header className="h-14 border-b border-white/5 px-8 flex items-center justify-between flex-shrink-0">
      <h1 className="text-sm font-semibold text-text-primary">{title}</h1>
      <div className="flex items-center gap-3">
        <div className="w-8 h-8 rounded-full bg-surface-2 border border-white/10 flex items-center justify-center cursor-pointer hover:bg-surface-3 transition-colors">
          <User className="w-4 h-4 text-text-secondary" />
        </div>
      </div>
    </header>
  );
}
