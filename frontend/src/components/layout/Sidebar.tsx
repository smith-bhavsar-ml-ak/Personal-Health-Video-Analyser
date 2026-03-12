"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { LayoutDashboard, Video, History, MessageSquare, Settings, Activity, X, Moon, Sun } from "lucide-react";
import { clsx } from "clsx";
import { useState } from "react";
import { useTheme } from "@/contexts/ThemeContext";

const NAV = [
  { href: "/",          label: "Dashboard", icon: LayoutDashboard },
  { href: "/analyze",   label: "Analyze",   icon: Video },
  { href: "/history",   label: "History",   icon: History },
  { href: "/assistant", label: "AI Coach",  icon: MessageSquare },
];

export default function Sidebar() {
  const pathname = usePathname();
  const { theme, toggle } = useTheme();
  const [showSettings, setShowSettings] = useState(false);

  return (
    <>
      {/* Settings modal */}
      {showSettings && (
        <div
          className="fixed inset-0 bg-black/50 flex items-center justify-center z-50"
          onClick={() => setShowSettings(false)}
        >
          <div
            className="bg-surface-2 border border-white/10 rounded-modal w-80 p-6 space-y-5"
            onClick={(e) => e.stopPropagation()}
          >
            {/* Header */}
            <div className="flex items-center justify-between">
              <h2 className="text-sm font-semibold text-text-primary">Settings</h2>
              <button
                onClick={() => setShowSettings(false)}
                className="w-7 h-7 rounded-lg flex items-center justify-center hover:bg-surface-3 text-text-muted hover:text-text-primary transition-colors cursor-pointer"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            {/* Theme picker */}
            <div className="space-y-2">
              <p className="text-xs text-text-muted uppercase tracking-widest font-medium">Theme</p>
              <div className="grid grid-cols-2 gap-2">
                <button
                  onClick={() => theme !== "dark" && toggle()}
                  className={clsx(
                    "flex items-center justify-center gap-2 px-3 py-2.5 rounded-lg text-sm border transition-colors cursor-pointer",
                    theme === "dark"
                      ? "bg-surface border-primary text-primary"
                      : "bg-surface border-white/10 text-text-secondary hover:bg-surface-3"
                  )}
                >
                  <Moon className="w-4 h-4" />
                  Dark
                </button>
                <button
                  onClick={() => theme !== "light" && toggle()}
                  className={clsx(
                    "flex items-center justify-center gap-2 px-3 py-2.5 rounded-lg text-sm border transition-colors cursor-pointer",
                    theme === "light"
                      ? "bg-surface border-primary text-primary"
                      : "bg-surface border-white/10 text-text-secondary hover:bg-surface-3"
                  )}
                >
                  <Sun className="w-4 h-4" />
                  Light
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Sidebar */}
      <aside className="w-60 flex-shrink-0 flex flex-col bg-sidebar border-r border-white/5 h-full">
        {/* Logo */}
        <div className="h-14 flex items-center gap-3 px-5 border-b border-white/5">
          <div className="w-7 h-7 rounded-lg bg-primary/20 flex items-center justify-center">
            <Activity className="w-4 h-4 text-primary" />
          </div>
          <span className="font-semibold text-sm text-text-primary tracking-tight">HealthVision AI</span>
        </div>

        {/* Nav */}
        <nav className="flex-1 px-3 py-4 flex flex-col gap-0.5">
          {NAV.map(({ href, label, icon: Icon }) => {
            const active = pathname === href || (href !== "/" && pathname.startsWith(href));
            return (
              <Link
                key={href}
                href={href}
                className={clsx(
                  "flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm transition-colors duration-150 cursor-pointer",
                  active
                    ? "bg-surface-2 text-primary font-medium border-l-2 border-primary"
                    : "text-text-secondary hover:text-text-primary hover:bg-surface-2/60"
                )}
              >
                <Icon className="w-4 h-4 flex-shrink-0" />
                {label}
              </Link>
            );
          })}
        </nav>

        {/* Settings button */}
        <div className="px-3 py-4 border-t border-white/5">
          <button
            onClick={() => setShowSettings(true)}
            className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm text-text-secondary hover:text-text-primary hover:bg-surface-2/60 transition-colors duration-150 cursor-pointer"
          >
            <Settings className="w-4 h-4 flex-shrink-0" />
            Settings
          </button>
        </div>
      </aside>
    </>
  );
}
