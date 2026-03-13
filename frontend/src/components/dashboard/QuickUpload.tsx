"use client";
import { useRouter } from "next/navigation";
import { Upload, ArrowRight } from "lucide-react";

export default function QuickUpload() {
  const router = useRouter();

  return (
    <button
      onClick={() => router.push("/analyze")}
      className="w-full h-full bg-surface border-2 border-dashed border-white/[0.09] rounded-card p-6 flex flex-col items-center justify-center gap-4 cursor-pointer hover:border-primary/40 hover:bg-primary/[0.03] transition-all duration-200 group text-left"
    >
      <div className="w-12 h-12 rounded-xl bg-primary/10 border border-primary/15 flex items-center justify-center group-hover:bg-primary/20 group-hover:border-primary/25 transition-all duration-200">
        <Upload className="w-5 h-5 text-primary" />
      </div>

      <div className="text-center space-y-1">
        <p className="text-sm font-semibold text-text-primary">Analyze New Workout</p>
        <p className="text-xs text-text-muted leading-relaxed">
          Upload a video clip to get AI-powered form coaching and rep counting
        </p>
      </div>

      <span className="flex items-center gap-1.5 text-xs font-medium text-primary/70 group-hover:text-primary transition-colors duration-150">
        Get started
        <ArrowRight className="w-3 h-3 group-hover:translate-x-0.5 transition-transform duration-150" />
      </span>
    </button>
  );
}
