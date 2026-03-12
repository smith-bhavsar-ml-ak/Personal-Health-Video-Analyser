"use client";
import { useState, useRef, useEffect, Suspense } from "react";
import { useSearchParams } from "next/navigation";
import { Send, Mic, MicOff, X } from "lucide-react";
import { api } from "@/lib/api";
import MessageBubble from "@/components/assistant/MessageBubble";
import SuggestionChips from "@/components/assistant/SuggestionChips";

interface Message {
  role: "user" | "assistant";
  text: string;
  timestamp: string;
  audio_b64?: string | null;
}

function AssistantChat() {
  const searchParams = useSearchParams();
  const sessionId    = searchParams.get("session");

  const [messages, setMessages]   = useState<Message[]>([]);
  const [input, setInput]         = useState("");
  const [loading, setLoading]     = useState(false);
  const [recording, setRecording] = useState(false);
  const bottomRef = useRef<HTMLDivElement>(null);
  const mediaRef  = useRef<MediaRecorder | null>(null);
  const chunksRef = useRef<Blob[]>([]);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  useEffect(() => {
    if (messages.length === 0 && sessionId) {
      setMessages([{
        role: "assistant",
        text: "I've loaded your workout session. What would you like to know?",
        timestamp: new Date().toISOString(),
      }]);
    } else if (messages.length === 0) {
      setMessages([{
        role: "assistant",
        text: "Hi! I'm your AI Coach. Ask me anything about your workouts, or select a session from History first for specific insights.",
        timestamp: new Date().toISOString(),
      }]);
    }
  }, [sessionId]);

  const sendText = async (text: string) => {
    if (!text.trim()) return;
    if (!sessionId) {
      setMessages((m) => [...m,
        { role: "user", text, timestamp: new Date().toISOString() },
        { role: "assistant", text: "Please select a workout session first. Go to History, open a session, and use the Ask Coach button to chat about it.", timestamp: new Date().toISOString() },
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
            { role: "assistant", text: "Please select a workout session first before using voice queries.", timestamp: new Date().toISOString() },
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
      {/* Session context pill */}
      {sessionId && (
        <div className="flex items-center gap-2 w-fit">
          <span className="text-xs bg-primary/10 border border-primary/20 text-primary/80 px-3 py-1 rounded-full flex items-center gap-2">
            Viewing session context
            <button onClick={() => window.history.replaceState({}, "", "/assistant")} className="hover:text-danger cursor-pointer">
              <X className="w-3 h-3" />
            </button>
          </span>
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
        {messages.length <= 1 && !sessionId && (
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
          placeholder={sessionId ? "Ask your AI coach..." : "Select a session first to ask workout-specific questions"}
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
