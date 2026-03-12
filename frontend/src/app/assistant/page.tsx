"use client";
import { useState, useRef, useEffect, Suspense } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Send, Mic, MicOff, X, ChevronRight } from "lucide-react";
import { clsx } from "clsx";
import { api } from "@/lib/api";
import type { SessionSummary } from "@/lib/types";
import { EXERCISE_LABELS } from "@/lib/types";
import MessageBubble from "@/components/assistant/MessageBubble";
import SuggestionChips from "@/components/assistant/SuggestionChips";

interface Message {
  role: "user" | "assistant";
  text: string;
  timestamp: string;
  audio_b64?: string | null;
}

function AssistantChat() {
  const router       = useRouter();
  const searchParams = useSearchParams();
  const sessionId    = searchParams.get("session");

  const [messages, setMessages]   = useState<Message[]>([]);
  const [input, setInput]         = useState("");
  const [loading, setLoading]     = useState(false);
  const [recording, setRecording] = useState(false);
  const [sessions, setSessions]   = useState<SessionSummary[]>([]);
  const bottomRef = useRef<HTMLDivElement>(null);
  const mediaRef  = useRef<MediaRecorder | null>(null);
  const chunksRef = useRef<Blob[]>([]);

  // Fetch sessions list when no session is selected
  useEffect(() => {
    if (!sessionId) {
      api.listSessions()
        .then((all) => setSessions(all.filter((s) => s.status === "completed")))
        .catch(() => {});
    }
  }, [sessionId]);

  // Reset conversation when session changes
  useEffect(() => {
    setMessages([{
      role: "assistant",
      text: sessionId
        ? "I've loaded your workout session. What would you like to know?"
        : "Hi! I'm your AI Coach. Select a session below to ask specific questions about a workout.",
      timestamp: new Date().toISOString(),
    }]);
  }, [sessionId]);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  const selectSession = (id: string) => {
    router.push(`/assistant?session=${id}`);
  };

  const sendText = async (text: string) => {
    if (!text.trim()) return;
    if (!sessionId) {
      setMessages((m) => [...m,
        { role: "user", text, timestamp: new Date().toISOString() },
        { role: "assistant", text: "Please select a workout session below first.", timestamp: new Date().toISOString() },
      ]);
      setInput("");
      return;
    }
    const userMsg: Message = { role: "user", text, timestamp: new Date().toISOString() };
    setMessages((m) => [...m, userMsg]);
    setInput("");
    setLoading(true);

    try {
      const res = await api.voiceQuery(sessionId, { query_text: text });
      setMessages((m) => [...m, {
        role: "assistant",
        text: res.response_text,
        timestamp: new Date().toISOString(),
        audio_b64: res.audio_b64,
      }]);
    } catch (err) {
      const msg = err instanceof Error ? err.message : "Unknown error";
      setMessages((m) => [...m, { role: "assistant", text: `Error: ${msg}`, timestamp: new Date().toISOString() }]);
    } finally {
      setLoading(false);
    }
  };

  const startRecording = async () => {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    const recorder = new MediaRecorder(stream);
    chunksRef.current = [];
    recorder.ondataavailable = (e) => chunksRef.current.push(e.data);
    recorder.onstop = async () => {
      const blob = new Blob(chunksRef.current, { type: "audio/wav" });
      const reader = new FileReader();
      reader.onloadend = async () => {
        const b64 = (reader.result as string).split(",")[1];
        if (!sessionId) {
          setMessages((m) => [...m,
            { role: "user", text: "(Voice query)", timestamp: new Date().toISOString() },
            { role: "assistant", text: "Please select a workout session below first.", timestamp: new Date().toISOString() },
          ]);
          return;
        }
        setLoading(true);
        try {
          const res = await api.voiceQuery(sessionId, { audio_b64: b64 });
          setMessages((m) => [...m,
            { role: "user", text: res.query_text, timestamp: new Date().toISOString() },
            { role: "assistant", text: res.response_text, timestamp: new Date().toISOString(), audio_b64: res.audio_b64 },
          ]);
        } catch (err) {
          const msg = err instanceof Error ? err.message : "Unknown error";
          setMessages((m) => [...m, { role: "assistant", text: `Voice error: ${msg}`, timestamp: new Date().toISOString() }]);
        } finally {
          setLoading(false);
        }
      };
      reader.readAsDataURL(blob);
      stream.getTracks().forEach((t) => t.stop());
    };
    recorder.start();
    mediaRef.current = recorder;
    setRecording(true);
  };

  const stopRecording = () => {
    mediaRef.current?.stop();
    setRecording(false);
  };

  return (
    <div className="max-w-3xl mx-auto h-[calc(100vh-8rem)] flex flex-col gap-4">
      {/* Session context pill (when session selected) */}
      {sessionId && (
        <div className="flex items-center gap-2 w-fit">
          <span className="text-xs bg-primary/10 border border-primary/20 text-primary/80 px-3 py-1 rounded-full flex items-center gap-2">
            Viewing session context
            <button
              onClick={() => router.push("/assistant")}
              className="hover:text-danger cursor-pointer"
            >
              <X className="w-3 h-3" />
            </button>
          </span>
        </div>
      )}

      {/* Session picker (when no session selected) */}
      {!sessionId && sessions.length > 0 && (
        <div className="bg-surface border border-white/[0.07] rounded-card overflow-hidden flex-shrink-0">
          <p className="text-xs text-text-muted px-4 pt-3 pb-2 uppercase tracking-widest font-medium">
            Select a session
          </p>
          {sessions.map((s, i) => (
            <button
              key={s.id}
              onClick={() => selectSession(s.id)}
              className={clsx(
                "w-full flex items-center gap-3 px-4 py-3 hover:bg-surface-2 transition-colors text-left cursor-pointer",
                i < sessions.length - 1 && "border-b border-white/5"
              )}
            >
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 flex-wrap">
                  <span className="text-sm text-text-primary">
                    {new Date(s.created_at).toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" })}
                  </span>
                  {s.exercise_types.map((t) => (
                    <span key={t} className="text-xs bg-primary/10 text-primary/80 px-1.5 py-0.5 rounded">
                      {EXERCISE_LABELS[t]}
                    </span>
                  ))}
                </div>
                <p className="text-xs text-text-muted mt-0.5">
                  {s.total_reps} reps · {" "}
                  <span className={clsx({
                    "text-health":  s.avg_form_score >= 80,
                    "text-warning": s.avg_form_score >= 60 && s.avg_form_score < 80,
                    "text-danger":  s.avg_form_score < 60,
                  })}>
                    {s.avg_form_score.toFixed(0)}% form
                  </span>
                </p>
              </div>
              <ChevronRight className="w-4 h-4 text-text-muted flex-shrink-0" />
            </button>
          ))}
        </div>
      )}

      {/* Conversation */}
      <div className="flex-1 overflow-y-auto flex flex-col gap-4 pb-2">
        {messages.map((m, i) => <MessageBubble key={i} message={m} />)}
        {loading && (
          <div className="self-start flex gap-2 items-center px-4 py-3 bg-surface border border-white/[0.07] rounded-xl rounded-tl-none">
            <span className="w-1.5 h-1.5 bg-primary rounded-full animate-bounce" style={{ animationDelay: "0ms" }} />
            <span className="w-1.5 h-1.5 bg-primary rounded-full animate-bounce" style={{ animationDelay: "150ms" }} />
            <span className="w-1.5 h-1.5 bg-primary rounded-full animate-bounce" style={{ animationDelay: "300ms" }} />
          </div>
        )}
        {messages.length <= 1 && sessionId && (
          <div className="mt-4">
            <p className="text-xs text-text-muted mb-3">Suggested questions</p>
            <SuggestionChips onSelect={sendText} />
          </div>
        )}
        <div ref={bottomRef} />
      </div>

      {/* Input bar */}
      <div className="flex gap-2 items-center bg-surface-2 border border-white/[0.07] rounded-xl px-4 py-3 flex-shrink-0">
        <button
          onMouseDown={startRecording}
          onMouseUp={stopRecording}
          className={`w-9 h-9 rounded-lg flex items-center justify-center flex-shrink-0 cursor-pointer transition-colors ${
            recording ? "bg-primary/20 border border-primary animate-pulse" : "hover:bg-surface-3"
          }`}
        >
          {recording ? <MicOff className="w-4 h-4 text-primary" /> : <Mic className="w-4 h-4 text-text-muted" />}
        </button>

        <input
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && !e.shiftKey && sendText(input)}
          placeholder={sessionId ? "Ask your AI coach..." : "Select a session above to ask workout-specific questions"}
          className="flex-1 bg-transparent text-sm text-text-primary placeholder:text-text-muted outline-none"
        />

        <button
          onClick={() => sendText(input)}
          disabled={!input.trim() || loading}
          className="w-9 h-9 rounded-lg bg-primary hover:bg-primary-dim disabled:opacity-30 disabled:cursor-not-allowed flex items-center justify-center flex-shrink-0 cursor-pointer transition-colors"
        >
          <Send className="w-4 h-4 text-white" />
        </button>
      </div>
    </div>
  );
}

export default function AssistantPage() {
  return (
    <Suspense>
      <AssistantChat />
    </Suspense>
  );
}
