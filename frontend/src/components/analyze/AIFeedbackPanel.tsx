import { Bot } from "lucide-react";

interface Props { feedback: string }

export default function AIFeedbackPanel({ feedback }: Props) {
  return (
    <div className="relative bg-surface border border-primary/15 rounded-card p-5 overflow-hidden">
      {/* Decorative quote mark */}
      <span
        className="absolute top-2 right-4 text-6xl text-primary/[0.07] font-serif leading-none select-none pointer-events-none"
        aria-hidden="true"
      >
        &ldquo;
      </span>

      <div className="flex gap-4 relative">
        <div className="w-8 h-8 rounded-full bg-primary/10 border border-primary/20 flex items-center justify-center flex-shrink-0 mt-0.5">
          <Bot className="w-4 h-4 text-primary" />
        </div>
        <div>
          <p className="text-[10px] font-semibold text-primary/80 uppercase tracking-widest mb-2">AI Coach Analysis</p>
          <p className="text-sm text-text-secondary leading-[1.7]">{feedback}</p>
        </div>
      </div>
    </div>
  );
}
