"use client";
import { useRouter } from "next/navigation";
import { Upload } from "lucide-react";

export default function QuickUpload() {
  const router = useRouter();

  return (
    <div
      onClick={() => router.push("/analyze")}
      className="bg-surface border-2 border-dashed border-white/10 rounded-card p-6 flex flex-col items-center gap-3 cursor-pointer hover:border-primary/50 hover:bg-primary/[0.03] transition-all duration-150 group"
    >
      <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center group-hover:bg-primary/20 transition-colors">
        <Upload className="w-5 h-5 text-primary" />
      </div>
      <div className="text-center">
        <p className="text-sm font-medium text-text-primary">Analyze a new workout</p>
        <p className="text-xs text-text-muted mt-0.5">Upload a video to get AI coaching feedback</p>
      </div>
    </div>
  );
}
