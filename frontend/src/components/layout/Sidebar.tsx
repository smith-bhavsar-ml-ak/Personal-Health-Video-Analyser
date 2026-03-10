"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { LayoutDashboard, Video, History, MessageSquare, Settings, Activity } from "lucide-react";
import { clsx } from "clsx";

const NAV = [
  { href: "/",          label: "Dashboard",    icon: LayoutDashboard },
  { href: "/analyze",   label: "Analyze",      icon: Video },
  { href: "/history",   label: "History",      icon: History },
  { href: "/assistant", label: "AI Coach",     icon: MessageSquare },
];

export default function Sidebar() {
  const pathname = usePathname();

  return (
    <aside className="w-60 flex-shrink-0 flex flex-col bg-[#0D0D14] border-r border-white/5 h-full">
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

      {/* Settings */}
      <div className="px-3 py-4 border-t border-white/5">
        <Link
          href="/settings"
          className="flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm text-text-secondary hover:text-text-primary hover:bg-surface-2/60 transition-colors duration-150 cursor-pointer"
        >
          <Settings className="w-4 h-4 flex-shrink-0" />
          Settings
        </Link>
      </div>
    </aside>
  );
}
