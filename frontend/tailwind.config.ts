import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        bg: "#0A0A0F",
        surface: "#111118",
        "surface-2": "#16161F",
        "surface-3": "#1C1C28",
        primary: "#6366F1",
        "primary-dim": "#4F46E5",
        health: "#10B981",
        "health-dim": "#059669",
        warning: "#F59E0B",
        danger: "#EF4444",
        info: "#38BDF8",
        "text-primary": "#F1F5F9",
        "text-secondary": "#94A3B8",
        "text-muted": "#475569",
        "border-base": "rgba(255,255,255,0.07)",
        "border-hover": "rgba(255,255,255,0.14)",
      },
      fontFamily: {
        sans: ["Inter", "system-ui", "sans-serif"],
        mono: ["JetBrains Mono", "Fira Code", "monospace"],
      },
      borderRadius: {
        card: "12px",
        modal: "16px",
      },
      boxShadow: {
        card: "0 1px 3px rgba(0,0,0,0.4), 0 1px 2px rgba(0,0,0,0.3)",
        elevated: "0 4px 16px rgba(0,0,0,0.5)",
        "primary-glow": "0 0 20px rgba(99,102,241,0.25)",
        "health-glow": "0 0 20px rgba(16,185,129,0.2)",
      },
    },
  },
  plugins: [],
};

export default config;
