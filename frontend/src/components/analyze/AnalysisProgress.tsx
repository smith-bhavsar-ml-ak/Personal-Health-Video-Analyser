import { CheckCircle, Circle, Loader2 } from "lucide-react";

const STEPS = [
  "Extracting frames",
  "Detecting pose landmarks",
  "Analysing exercise & reps",
  "Generating AI feedback",
];

interface Props { currentStep: number }

export default function AnalysisProgress({ currentStep }: Props) {
  const pct = Math.round(((currentStep) / STEPS.length) * 100);

  return (
    <div className="bg-surface border border-white/[0.07] rounded-card p-6 flex flex-col gap-5">
      <div className="flex items-center gap-3">
        <Loader2 className="w-5 h-5 text-primary animate-spin" />
        <span className="text-sm font-medium text-text-primary">Analysing your workout...</span>
      </div>

      {/* Progress bar */}
      <div className="h-1.5 bg-surface-3 rounded-full overflow-hidden">
        <div
          className="h-full bg-primary rounded-full transition-all duration-500"
          style={{ width: `${pct}%` }}
        />
      </div>

      {/* Steps */}
      <div className="flex flex-col gap-2.5">
        {STEPS.map((step, i) => {
          const done    = i < currentStep;
          const active  = i === currentStep;
          const pending = i > currentStep;
          return (
            <div key={step} className="flex items-center gap-3">
              {done    && <CheckCircle className="w-4 h-4 text-health flex-shrink-0" />}
              {active  && <Loader2    className="w-4 h-4 text-primary animate-spin flex-shrink-0" />}
              {pending && <Circle     className="w-4 h-4 text-text-muted flex-shrink-0" />}
              <span className={`text-sm ${done ? "text-health" : active ? "text-text-primary" : "text-text-muted"}`}>
                {step}
              </span>
            </div>
          );
        })}
      </div>
    </div>
  );
}
