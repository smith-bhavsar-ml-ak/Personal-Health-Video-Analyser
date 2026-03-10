import { MessageSquare } from "lucide-react";

interface Props { feedback: string }

export default function AIFeedbackPanel({ feedback }: Props) {
  return (
    <div className="bg-surface-3 border border-white/[0.07] border-l-2 border-l-primary rounded-card p-5 flex gap-4">
      <div className="w-8 h-8 rounded-lg bg-primary/10 flex items-center justify-center flex-shrink-0 mt-0.5">
        <MessageSquare className="w-4 h-4 text-primary" />
      </div>
      <div>
        <p className="text-xs font-semibold text-primary uppercase tracking-widest mb-2">AI Coach</p>
        <p className="text-sm text-text-secondary leading-relaxed">{feedback}</p>
      </div>
    </div>
  );
}
