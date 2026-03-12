import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        // Theme-aware: backed by CSS variables so dark/light toggle works.
        // The `<alpha-value>` token lets Tailwind's opacity modifiers work (e.g. bg-surface-2/60).
        bg:             "rgb(var(--color-bg)         / <alpha-value>)",
        surface:        "rgb(var(--color-surface)    / <alpha-value>)",
        "surface-2":    "rgb(var(--color-surface-2)  / <alpha-value>)",
        "surface-3":    "rgb(var(--color-surface-3)  / <alpha-value>)",
        sidebar:        "rgb(var(--color-sidebar)    / <alpha-value>)",
        "text-primary":   "rgb(var(--color-text-primary)   / <alpha-value>)",
        "text-secondary": "rgb(var(--color-text-secondary) / <alpha-value>)",
        "text-muted":     "rgb(var(--color-text-muted)     / <alpha-value>)",
        // Static brand / status colours — unchanged by theme
        primary:        "#6366F1",
        "primary-dim":  "#4F46E5",
        health:         "#10B981",
        "health-dim":   "#059669",
        warning:        "#F59E0B",
        danger:         "#EF4444",
        info:           "#38BDF8",
        "border-base":  "rgba(255,255,255,0.07)",
        "border-hover": "rgba(255,255,255,0.14)",
      },
      fontFamily: {
        sans: ["Inter", "system-ui", "sans-serif"],
        mono: ["JetBrains Mono", "Fira Code", "monospace"],
      },
      borderRadius: {
        card:  "12px",
        modal: "16px",
      },
      boxShadow: {
        card:           "0 1px 3px rgba(0,0,0,0.4), 0 1px 2px rgba(0,0,0,0.3)",
        elevated:       "0 4px 16px rgba(0,0,0,0.5)",
        "primary-glow": "0 0 20px rgba(99,102,241,0.25)",
        "health-glow":  "0 0 20px rgba(16,185,129,0.2)",
      },
    },
  },
  plugins: [],
};

export default config;
