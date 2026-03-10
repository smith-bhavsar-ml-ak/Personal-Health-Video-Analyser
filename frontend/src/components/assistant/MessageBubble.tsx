import { clsx } from "clsx";
import { Bot } from "lucide-react";

interface Message {
  role: "user" | "assistant";
  text: string;
  timestamp: string;
  audio_b64?: string | null;
}

interface Props { message: Message }

export default function MessageBubble({ message }: Props) {
  const isAI = message.role === "assistant";

  return (
    <div className={clsx("flex gap-3 max-w-[75%]", isAI ? "self-start" : "self-end flex-row-reverse")}>
      {isAI && (
        <div className="w-8 h-8 rounded-full bg-primary/10 border border-primary/20 flex items-center justify-center flex-shrink-0 mt-1">
          <Bot className="w-4 h-4 text-primary" />
        </div>
      )}
      <div className={clsx(
        "rounded-xl px-4 py-3 text-sm leading-relaxed",
        isAI
          ? "bg-surface border border-white/[0.07] rounded-tl-none text-text-secondary"
          : "bg-primary/15 border border-primary/20 rounded-tr-none text-text-primary"
      )}>
        <p>{message.text}</p>
        {isAI && message.audio_b64 && (
          <AudioPlayer audio_b64={message.audio_b64} />
        )}
        <p className="text-xs text-text-muted mt-1.5 opacity-0 hover:opacity-100 transition-opacity">
          {new Date(message.timestamp).toLocaleTimeString("en-US", { hour: "2-digit", minute: "2-digit" })}
        </p>
      </div>
    </div>
  );
}

function AudioPlayer({ audio_b64 }: { audio_b64: string }) {
  const src = `data:audio/wav;base64,${audio_b64}`;
  return (
    <audio controls src={src} className="mt-2 h-8 w-40 opacity-70 hover:opacity-100 transition-opacity" />
  );
}
