"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { MessageSquare } from "lucide-react";
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

  const handleAnalyze = async () => {
    if (!file) return;
    setPhase("processing");
    setStep(0);

    // Simulate progress steps while waiting for API
    const stepTimer = setInterval(() => setStep((s) => Math.min(s + 1, 3)), 3000);

    try {
      const data = await api.analyzeVideo(file);
      clearInterval(stepTimer);
      setStep(4);
      setResult(data);
      setPhase("done");
    } catch (e: unknown) {
      clearInterval(stepTimer);
      setErrorMsg(e instanceof Error ? e.message : "Analysis failed");
      setPhase("error");
    }
  };

  return (
    <div className="max-w-3xl mx-auto space-y-6">
      {/* Upload zone — always visible */}
      <div className="space-y-4">
        <div>
          <h2 className="text-xl font-bold text-text-primary">Upload Workout Video</h2>
          <p className="text-sm text-text-muted mt-0.5">Upload a short clip (under 2 min) to get AI analysis and coaching</p>
        </div>

        <VideoUploader onFile={setFile} disabled={phase === "processing"} />

        {file && phase === "idle" && (
          <button
            onClick={handleAnalyze}
            className="w-full bg-primary hover:bg-primary-dim text-white font-medium py-3 rounded-xl transition-colors duration-150 cursor-pointer text-sm"
          >
            Analyze Workout
          </button>
        )}

        {phase === "error" && (
          <div className="bg-danger/10 border border-danger/20 rounded-xl p-4 text-sm text-danger">
            {errorMsg}
          </div>
        )}
      </div>

      {/* Processing */}
      {phase === "processing" && <AnalysisProgress currentStep={step} />}

      {/* Results */}
      {phase === "done" && result && (
        <div className="space-y-4 animate-fade-in-up">
          <div className="flex items-center justify-between">
            <div>
              <h3 className="text-lg font-bold text-text-primary">Analysis Complete</h3>
              <p className="text-xs text-text-muted mt-0.5">
                {new Date(result.created_at).toLocaleString()}
              </p>
            </div>
            <div className="flex gap-2">
              <button
                onClick={() => { setFile(null); setPhase("idle"); setResult(null); setStep(0); }}
                className="text-sm px-4 py-2 rounded-lg border border-white/10 text-text-secondary hover:bg-surface-2 transition-colors cursor-pointer"
              >
                Analyze Another
              </button>
            </div>
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
            className="flex items-center gap-3 bg-surface border border-white/[0.07] rounded-card p-4 hover:bg-surface-2 transition-colors cursor-pointer"
          >
            <div className="w-8 h-8 rounded-lg bg-primary/10 flex items-center justify-center">
              <MessageSquare className="w-4 h-4 text-primary" />
            </div>
            <div>
              <p className="text-sm font-medium text-text-primary">Ask your AI Coach</p>
              <p className="text-xs text-text-muted">Voice or text queries about this workout</p>
            </div>
          </Link>
        </div>
      )}
    </div>
  );
}
