import { CheckCircle, Loader2 } from "lucide-react";

const STEPS = [
  { label: "Extracting frames",          desc: "Breaking video into frames" },
  { label: "Detecting pose landmarks",   desc: "Running MediaPipe on each frame" },
  { label: "Analysing exercise & reps",  desc: "Classifying exercise and counting reps" },
  { label: "Generating AI feedback",     desc: "Asking your AI coach for coaching tips" },
];

interface Props { currentStep: number }

export default function AnalysisProgress({ currentStep }: Props) {
  const pct = Math.round((currentStep / STEPS.length) * 100);

  return (
    <div className="bg-surface border border-white/[0.07] rounded-card p-6 space-y-5">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          <Loader2 className="w-5 h-5 text-primary animate-spin flex-shrink-0" />
          <span className="text-sm font-semibold text-text-primary">Analysing your workout</span>
        </div>
        <span className="text-xs font-mono text-text-muted">{pct}%</span>
      </div>

      {/* Progress bar */}
      <div className="h-1 bg-surface-3 rounded-full overflow-hidden">
        <div
          className="h-full bg-primary rounded-full transition-all duration-700 ease-out"
          style={{ width: `${pct}%` }}
        />
      </div>

      {/* Steps with connecting line */}
      <div className="relative flex flex-col gap-0">
        {/* Vertical connector */}
        <div className="absolute left-[9px] top-5 bottom-5 w-px bg-white/[0.06]" />

        {STEPS.map((step, i) => {
          const done   = i < currentStep;
          const active = i === currentStep;
          return (
            <div key={step.label} className="flex items-start gap-4 py-2.5 relative">
              {/* Icon */}
              <div className="flex-shrink-0 z-10">
                {done
                  ? <CheckCircle className="w-[18px] h-[18px] text-health" />
                  : active
                  ? <Loader2 className="w-[18px] h-[18px] text-primary animate-spin" />
                  : <div className="w-[18px] h-[18px] rounded-full border-2 border-white/[0.12] bg-surface" />}
              </div>
              {/* Text */}
              <div>
                <p className={`text-sm font-medium leading-none ${done ? "text-health" : active ? "text-text-primary" : "text-text-muted"}`}>
                  {step.label}
                </p>
                {active && (
                  <p className="text-xs text-text-muted mt-1">{step.desc}</p>
                )}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
