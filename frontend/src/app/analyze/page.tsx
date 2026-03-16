"use client";
import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { MessageSquare, RotateCcw, Sparkles, ChevronRight } from "lucide-react";
import { api } from "@/lib/api";
import type { SessionResult } from "@/lib/types";
import VideoUploader from "@/components/analyze/VideoUploader";
import AnalysisProgress from "@/components/analyze/AnalysisProgress";
import ExerciseCard from "@/components/analyze/ExerciseCard";
import AIFeedbackPanel from "@/components/analyze/AIFeedbackPanel";

type Phase = "idle" | "processing" | "done" | "error";

export default function AnalyzePage() {
  const router = useRouter();
  const [file, setFile]         = useState<File | null>(null);
  const [phase, setPhase]       = useState<Phase>("idle");
  const [step, setStep]         = useState(0);
  const [result, setResult]     = useState<SessionResult | null>(null);
  const [errorMsg, setErrorMsg] = useState("");
  const pollRef = useRef<ReturnType<typeof setInterval> | null>(null);

  // Clean up poll on unmount
  useEffect(() => () => { if (pollRef.current) clearInterval(pollRef.current); }, []);

  const handleAnalyze = async () => {
    if (!file) return;
    setPhase("processing");
    setStep(0);

    try {
      // Upload immediately — backend queues background task and returns status="processing"
      const initial = await api.analyzeVideo(file);

      // Poll every 2 s until the background task finishes
      pollRef.current = setInterval(async () => {
        setStep((s) => Math.min(s + 1, 3));
        try {
          const session = await api.getSession(initial.id);
          if (session.status === "completed") {
            clearInterval(pollRef.current!);
            setStep(4);
            setResult(session);
            setPhase("done");
            router.refresh();
          } else if (session.status === "failed") {
            clearInterval(pollRef.current!);
            setErrorMsg("Analysis failed — please try again");
            setPhase("error");
          }
        } catch { /* ignore transient poll errors */ }
      }, 2000);
    } catch (e: unknown) {
      setErrorMsg(e instanceof Error ? e.message : "Analysis failed");
      setPhase("error");
    }
  };

  const reset = () => { setFile(null); setPhase("idle"); setResult(null); setStep(0); setErrorMsg(""); };

  return (
    <div className="max-w-3xl mx-auto space-y-6">
      {/* Upload zone — always visible */}
      <div className="space-y-4">
        <div>
          <h2 className="text-xl font-bold text-text-primary">Upload Workout Video</h2>
          <p className="text-sm text-text-muted mt-0.5">Upload a short clip (under 2 min) to get AI analysis and coaching feedback</p>
        </div>

        <VideoUploader onFile={setFile} disabled={phase === "processing"} />

        {file && phase === "idle" && (
          <button
            onClick={handleAnalyze}
            className="w-full flex items-center justify-center gap-2 bg-primary hover:bg-primary-dim text-white font-medium py-3 rounded-xl transition-colors duration-150 cursor-pointer text-sm"
          >
            <Sparkles className="w-4 h-4" />
            Analyze Workout
          </button>
        )}

        {phase === "error" && (
          <div className="bg-danger/10 border border-danger/20 rounded-xl p-4 flex items-start gap-3">
            <div className="w-8 h-8 rounded-lg bg-danger/10 flex items-center justify-center flex-shrink-0 mt-0.5">
              <span className="text-danger text-sm font-bold">!</span>
            </div>
            <div className="flex-1">
              <p className="text-sm font-medium text-danger">Analysis failed</p>
              <p className="text-xs text-danger/70 mt-0.5">{errorMsg}</p>
            </div>
            <button onClick={reset} className="text-xs text-text-muted hover:text-text-primary transition-colors cursor-pointer flex items-center gap-1">
              <RotateCcw className="w-3 h-3" /> Retry
            </button>
          </div>
        )}
      </div>

      {/* Processing */}
      {phase === "processing" && <AnalysisProgress currentStep={step} />}

      {/* Results */}
      {phase === "done" && result && (
        <div className="space-y-4 animate-fade-in-up">
          {/* Results header */}
          <div className="flex items-center justify-between">
            <div>
              <div className="flex items-center gap-2">
                <div className="w-2 h-2 rounded-full bg-health animate-pulse" />
                <h3 className="text-base font-bold text-text-primary">Analysis Complete</h3>
              </div>
              <p className="text-xs text-text-muted mt-0.5">
                {new Date(result.created_at).toLocaleString("en-US", { month: "short", day: "numeric", hour: "2-digit", minute: "2-digit" })}
                <span className="ml-2 text-primary/60">· {result.exercise_sets.length} set{result.exercise_sets.length !== 1 ? "s" : ""} detected</span>
              </p>
            </div>
            <button
              onClick={reset}
              className="flex items-center gap-1.5 text-xs px-3 py-2 rounded-lg border border-white/[0.09] text-text-secondary hover:bg-surface-2 hover:text-text-primary transition-colors cursor-pointer"
            >
              <RotateCcw className="w-3 h-3" />
              Analyze Another
            </button>
          </div>

          {/* Exercise cards */}
          {result.exercise_sets.map((set, i) => (
            <ExerciseCard key={set.id} set={set} delay={i * 80} />
          ))}

          {/* AI Feedback */}
          {result.ai_feedback && <AIFeedbackPanel feedback={result.ai_feedback.feedback_text} />}

          {/* Voice query shortcut */}
          <Link
            href={`/assistant?session=${result.id}`}
            className="flex items-center gap-3 bg-surface border border-white/[0.07] rounded-card p-4 hover:bg-surface-2 hover:border-primary/20 transition-all duration-150 cursor-pointer group"
          >
            <div className="w-9 h-9 rounded-lg bg-primary/10 border border-primary/15 flex items-center justify-center flex-shrink-0">
              <MessageSquare className="w-4 h-4 text-primary" />
            </div>
            <div className="flex-1">
              <p className="text-sm font-medium text-text-primary">Ask your AI Coach</p>
              <p className="text-xs text-text-muted mt-0.5">Voice or text queries about this workout session</p>
            </div>
            <ChevronRight className="w-4 h-4 text-text-muted/40 group-hover:text-text-muted group-hover:translate-x-0.5 transition-all" />
          </Link>
        </div>
      )}
    </div>
  );
}
