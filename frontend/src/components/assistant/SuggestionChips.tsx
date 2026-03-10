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
          className="text-left text-sm bg-surface border border-white/[0.07] rounded-lg px-3 py-3 text-text-secondary hover:border-primary/40 hover:text-primary transition-colors duration-150 cursor-pointer"
        >
          {s}
        </button>
      ))}
    </div>
  );
}
