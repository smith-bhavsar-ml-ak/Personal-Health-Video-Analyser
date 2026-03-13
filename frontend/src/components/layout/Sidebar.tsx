"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  LayoutDashboard, Video, History, MessageSquare,
  Settings, Activity, X, Moon, Sun,
} from "lucide-react";
import { clsx } from "clsx";
import { useState } from "react";
import { useTheme } from "@/contexts/ThemeContext";

const NAV = [
  { href: "/",          label: "Dashboard", icon: LayoutDashboard },
  { href: "/analyze",   label: "Analyze",   icon: Video           },
  { href: "/history",   label: "History",   icon: History         },
  { href: "/assistant", label: "AI Coach",  icon: MessageSquare   },
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
          className="fixed inset-0 bg-black/60 flex items-center justify-center z-50"
          onClick={() => setShowSettings(false)}
        >
          <div
            className="bg-surface-2 border border-white/[0.09] rounded-modal w-80 p-6 space-y-5 shadow-modal"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between">
              <h2 className="text-sm font-semibold text-text-primary">Settings</h2>
              <button
                onClick={() => setShowSettings(false)}
                aria-label="Close settings"
                className="w-8 h-8 rounded-lg flex items-center justify-center hover:bg-surface-3 text-text-muted hover:text-text-primary transition-colors cursor-pointer"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <div className="space-y-2">
              <p className="text-xs text-text-muted uppercase tracking-widest font-medium">Appearance</p>
              <div className="grid grid-cols-2 gap-2">
                {([
                  { value: "dark",  label: "Dark",  Icon: Moon },
                  { value: "light", label: "Light", Icon: Sun  },
                ] as const).map(({ value, label, Icon }) => (
                  <button
                    key={value}
                    onClick={() => theme !== value && toggle()}
                    className={clsx(
                      "flex items-center justify-center gap-2 px-3 py-2.5 rounded-lg text-sm border transition-colors duration-150 cursor-pointer",
                      theme === value
                        ? "bg-primary/10 border-primary/30 text-primary"
                        : "bg-surface border-white/[0.07] text-text-secondary hover:bg-surface-3 hover:border-white/[0.12]"
                    )}
                  >
                    <Icon className="w-4 h-4" />
                    {label}
                  </button>
                ))}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Sidebar */}
      <aside className="w-60 flex-shrink-0 flex flex-col bg-sidebar border-r border-white/[0.05] h-full">
        {/* Logo */}
        <div className="h-14 flex items-center gap-3 px-5 border-b border-white/[0.05]">
          <div className="w-7 h-7 rounded-lg bg-primary/20 border border-primary/20 flex items-center justify-center flex-shrink-0">
            <Activity className="w-3.5 h-3.5 text-primary" />
          </div>
          <div>
            <p className="font-semibold text-sm text-text-primary leading-none">HealthVision</p>
            <p className="text-[10px] text-text-muted mt-0.5">AI Coach</p>
          </div>
        </div>

        {/* Nav */}
        <nav className="flex-1 px-3 py-4 flex flex-col gap-0.5">
          <p className="text-[10px] text-text-muted uppercase tracking-widest font-medium px-3 mb-2">Navigation</p>
          {NAV.map(({ href, label, icon: Icon }) => {
            const active = pathname === href || (href !== "/" && pathname.startsWith(href));
            return (
              <Link
                key={href}
                href={href}
                className={clsx(
                  "flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm transition-all duration-150 cursor-pointer group",
                  active
                    ? "bg-primary/10 text-primary font-medium"
                    : "text-text-muted hover:text-text-secondary hover:bg-surface-2/80"
                )}
              >
                <Icon className={clsx(
                  "w-4 h-4 flex-shrink-0 transition-colors",
                  active ? "text-primary" : "text-text-muted group-hover:text-text-secondary"
                )} />
                {label}
              </Link>
            );
          })}
        </nav>

        {/* Settings */}
        <div className="px-3 pb-4 pt-3 border-t border-white/[0.05]">
          <button
            onClick={() => setShowSettings(true)}
            className="w-full flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm text-text-muted hover:text-text-secondary hover:bg-surface-2/80 transition-colors duration-150 cursor-pointer"
          >
            <Settings className="w-4 h-4 flex-shrink-0" />
            Settings
          </button>
        </div>
      </aside>
    </>
  );
}
