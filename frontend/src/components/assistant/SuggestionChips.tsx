import { MessageCircle } from "lucide-react";

const SUGGESTIONS = [
  "How was my squat form?",
  "How many reps did I do?",
  "What should I improve?",
  "Compare to last session",
];

interface Props { onSelect: (text: string) => void }

export default function SuggestionChips({ onSelect }: Props) {
  return (
    <div className="grid grid-cols-2 gap-2">
      {SUGGESTIONS.map((s) => (
        <button
          key={s}
          onClick={() => onSelect(s)}
          className="text-left text-sm bg-surface border border-white/[0.07] rounded-lg px-3 py-3 text-text-muted hover:border-primary/30 hover:bg-primary/[0.04] hover:text-text-secondary transition-all duration-150 cursor-pointer flex items-start gap-2 group"
        >
          <MessageCircle className="w-3.5 h-3.5 text-primary/40 group-hover:text-primary/70 mt-0.5 flex-shrink-0 transition-colors" />
          <span>{s}</span>
        </button>
      ))}
    </div>
  );
}
