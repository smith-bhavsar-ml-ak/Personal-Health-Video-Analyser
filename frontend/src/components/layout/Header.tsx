"use client";
import { usePathname } from "next/navigation";
import { User, LogOut, ChevronDown } from "lucide-react";
import { useState, useEffect, useRef } from "react";
import { api } from "@/lib/api";

const TITLES: Record<string, string> = {
  "/":          "Dashboard",
  "/analyze":   "Analyze Workout",
  "/history":   "Workout History",
  "/assistant": "AI Coach",
};

export default function Header() {
  const pathname = usePathname();
  const title = TITLES[pathname] ?? "HealthVision AI";

  const [email, setEmail]   = useState<string | null>(null);
  const [open, setOpen]     = useState(false);
  const dropdownRef         = useRef<HTMLDivElement>(null);

  useEffect(() => {
    api.getMe().then((u) => setEmail(u.email)).catch(() => {});
  }, []);

  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(e.target as Node)) {
        setOpen(false);
      }
    };
    document.addEventListener("mousedown", handler);
    return () => document.removeEventListener("mousedown", handler);
  }, []);

  const initials = email ? email[0].toUpperCase() : "?";

  return (
    <header className="h-14 border-b border-white/[0.05] px-8 flex items-center justify-between flex-shrink-0">
      <h1 className="text-sm font-semibold text-text-primary">{title}</h1>

      <div className="relative" ref={dropdownRef}>
        <button
          onClick={() => setOpen((v) => !v)}
          className="flex items-center gap-2 px-2 py-1.5 rounded-lg hover:bg-surface-2 transition-colors duration-150 cursor-pointer"
        >
          <div className="w-7 h-7 rounded-full bg-primary/10 border border-primary/20 flex items-center justify-center flex-shrink-0">
            {email
              ? <span className="text-[11px] font-semibold text-primary">{initials}</span>
              : <User className="w-3.5 h-3.5 text-text-muted" />}
          </div>
          {email && (
            <span className="text-xs text-text-muted max-w-[140px] truncate hidden sm:block">{email}</span>
          )}
          <ChevronDown className={`w-3.5 h-3.5 text-text-muted transition-transform duration-150 ${open ? "rotate-180" : ""}`} />
        </button>

        {open && (
          <div className="absolute right-0 top-full mt-1.5 w-52 bg-surface-2 border border-white/[0.09] rounded-xl shadow-modal overflow-hidden z-50">
            {email && (
              <div className="px-4 py-3 border-b border-white/[0.05]">
                <p className="text-[10px] text-text-muted uppercase tracking-widest font-medium">Signed in as</p>
                <p className="text-xs text-text-primary font-medium mt-0.5 truncate">{email}</p>
              </div>
            )}
            <div className="p-1">
              <button
                onClick={() => { setOpen(false); api.logout(); }}
                className="w-full flex items-center gap-2.5 px-3 py-2 rounded-lg text-sm text-text-muted hover:text-danger hover:bg-danger/10 transition-colors duration-150 cursor-pointer"
              >
                <LogOut className="w-3.5 h-3.5" />
                Sign out
              </button>
            </div>
          </div>
        )}
      </div>
    </header>
  );
}
