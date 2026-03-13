"use client";
import { useState, useRef, useEffect, Suspense } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { Send, Mic, X, Check, ChevronRight } from "lucide-react";
import { clsx } from "clsx";
import { api } from "@/lib/api";
import type { SessionSummary, ExerciseType } from "@/lib/types";
import { EXERCISE_LABELS } from "@/lib/types";
import MessageBubble from "@/components/assistant/MessageBubble";
import SuggestionChips from "@/components/assistant/SuggestionChips";

interface Message {
  role: "user" | "assistant";
  text: string;
  timestamp: string;
  audio_b64?: string | null;
}

const WAVE_BARS = 48;

// ── Voice Waveform ────────────────────────────────────────────────────────────
function VoiceWaveform({ data }: { data: number[] }) {
  return (
    <div className="flex-1 flex items-center justify-center gap-[2px] h-8 overflow-hidden">
      {data.map((v, i) => {
        const height = Math.max(3, v * 28);
        return (
          <div key={i} className="flex flex-col items-center gap-[1px]">
            {/* top half */}
            <div
              className="w-[3px] rounded-full bg-primary transition-all duration-75"
              style={{ height: `${height / 2}px`, opacity: 0.55 + v * 0.45 }}
            />
            {/* bottom half (mirror) */}
            <div
              className="w-[3px] rounded-full bg-primary transition-all duration-75"
              style={{ height: `${height / 2}px`, opacity: 0.55 + v * 0.45 }}
            />
          </div>
        );
      })}
    </div>
  );
}

// ── Main Chat ─────────────────────────────────────────────────────────────────
function AssistantChat() {
  const router       = useRouter();
  const searchParams = useSearchParams();
  const sessionId    = searchParams.get("session");

  const [messages, setMessages]             = useState<Message[]>([]);
  const [input, setInput]                   = useState("");
  const [loading, setLoading]               = useState(false);
  const [sessions, setSessions]             = useState<SessionSummary[]>([]);
  const [recording, setRecording]           = useState(false);
  const [liveTranscript, setLiveTranscript] = useState("");
  const [waveData, setWaveData]             = useState<number[]>(Array(WAVE_BARS).fill(0.05));

  const bottomRef         = useRef<HTMLDivElement>(null);
  const streamRef         = useRef<MediaStream | null>(null);
  const audioCtxRef       = useRef<AudioContext | null>(null);
  const animFrameRef      = useRef<number>(0);
  const recognitionRef    = useRef<any>(null);
  const transcriptRef     = useRef("");
  const prefersReducedRef = useRef(
    typeof window !== "undefined"
      ? window.matchMedia("(prefers-reduced-motion: reduce)").matches
      : false
  );

  useEffect(() => {
    if (!sessionId) {
      api.listSessions()
        .then((all) => setSessions(all.filter((s) => s.status === "completed")))
        .catch(() => {});
    }
  }, [sessionId]);

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

  useEffect(() => {
    return () => {
      cancelAnimationFrame(animFrameRef.current);
      streamRef.current?.getTracks().forEach((t) => t.stop());
      audioCtxRef.current?.close();
      recognitionRef.current?.stop();
    };
  }, []);

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
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      streamRef.current = stream;
      transcriptRef.current = "";
      setLiveTranscript("");

      // Waveform — skip animation when user prefers reduced motion
      if (!prefersReducedRef.current) {
        const audioCtx = new AudioContext();
        audioCtxRef.current = audioCtx;
        const source   = audioCtx.createMediaStreamSource(stream);
        const analyser = audioCtx.createAnalyser();
        analyser.fftSize = 256;
        source.connect(analyser);

        const tick = () => {
          const raw = new Uint8Array(analyser.frequencyBinCount);
          analyser.getByteFrequencyData(raw);
          const bars = Array.from({ length: WAVE_BARS }, (_, i) => {
            const idx = Math.floor((i / WAVE_BARS) * raw.length);
            return Math.max(0.04, raw[idx] / 255);
          });
          setWaveData(bars);
          animFrameRef.current = requestAnimationFrame(tick);
        };
        tick();
      }

      // Web Speech API for live transcript
      const SR = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;
      if (SR) {
        const recognition = new SR();
        recognition.continuous     = true;
        recognition.interimResults = true;
        recognition.lang           = "en-US";
        let finalText = "";
        recognition.onresult = (e: any) => {
          let interim = "";
          for (let i = e.resultIndex; i < e.results.length; i++) {
            if (e.results[i].isFinal) finalText += e.results[i][0].transcript + " ";
            else interim = e.results[i][0].transcript;
          }
          const combined = (finalText + interim).trim();
          transcriptRef.current = combined;
          setLiveTranscript(combined);
        };
        recognition.start();
        recognitionRef.current = recognition;
      }

      setRecording(true);
    } catch {
      // mic permission denied
    }
  };

  const stopRecording = (confirm: boolean) => {
    cancelAnimationFrame(animFrameRef.current);
    streamRef.current?.getTracks().forEach((t) => t.stop());
    audioCtxRef.current?.close();
    recognitionRef.current?.stop();

    if (confirm && transcriptRef.current.trim()) {
      setInput(transcriptRef.current.trim());
    }
    transcriptRef.current = "";
    setLiveTranscript("");
    setWaveData(Array(WAVE_BARS).fill(0.05));
    setRecording(false);
  };

  return (
    <div className="max-w-3xl mx-auto h-[calc(100vh-8rem)] flex flex-col gap-4">

      {/* Session context pill */}
      {sessionId && (
        <div className="flex items-center gap-2 w-fit">
          <span className="text-xs bg-primary/10 border border-primary/20 text-primary/80 px-3 py-1 rounded-full flex items-center gap-2">
            Viewing session context
            <button
              onClick={() => router.push("/assistant")}
              aria-label="Clear session"
              className="hover:text-danger cursor-pointer"
            >
              <X className="w-3 h-3" />
            </button>
          </span>
        </div>
      )}

      {/* Session picker */}
      {!sessionId && sessions.length > 0 && (
        <div className="bg-surface border border-white/[0.07] rounded-card overflow-hidden flex-shrink-0">
          <p className="text-xs text-text-muted px-4 pt-3 pb-2 uppercase tracking-widest font-medium">
            Select a session
          </p>
          {sessions.map((s, i) => (
            <button
              key={s.id}
              onClick={() => router.push(`/assistant?session=${s.id}`)}
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
                  {s.exercise_types.map((t: ExerciseType) => (
                    <span key={t} className="text-xs bg-primary/10 text-primary/80 px-1.5 py-0.5 rounded">
                      {EXERCISE_LABELS[t]}
                    </span>
                  ))}
                </div>
                <p className="text-xs text-text-muted mt-0.5">
                  {s.total_reps} reps ·{" "}
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

      {/* ── Input bar ──────────────────────────────────────────────────────── */}
      <div className="flex-shrink-0">
        {recording ? (
          /* ── Recording state ── */
          <div className="bg-surface-2 border border-primary/20 rounded-xl overflow-hidden transition-all duration-150">
            {/* Waveform row */}
            <div className="flex items-center gap-3 px-3 py-2.5">
              {/* Recording indicator */}
              <div className="flex items-center gap-1.5 flex-shrink-0 pl-1">
                <span className="w-2 h-2 rounded-full bg-danger animate-pulse" />
                <span className="text-xs text-text-muted font-medium tabular-nums">REC</span>
              </div>

              {/* Waveform */}
              <VoiceWaveform data={waveData} />

              {/* Cancel */}
              <button
                onClick={() => stopRecording(false)}
                aria-label="Cancel recording"
                className="w-9 h-9 rounded-lg flex items-center justify-center hover:bg-danger/10 text-text-muted hover:text-danger transition-colors duration-150 cursor-pointer flex-shrink-0"
              >
                <X className="w-4 h-4" />
              </button>

              {/* Confirm */}
              <button
                onClick={() => stopRecording(true)}
                aria-label="Use transcript"
                disabled={!liveTranscript.trim()}
                className="w-9 h-9 rounded-lg bg-primary/15 border border-primary/25 flex items-center justify-center hover:bg-primary/25 disabled:opacity-30 disabled:cursor-not-allowed transition-colors duration-150 cursor-pointer flex-shrink-0"
              >
                <Check className="w-4 h-4 text-primary" />
              </button>
            </div>

            {/* Live transcript */}
            <div className="border-t border-white/[0.06] px-4 py-2.5 min-h-[36px] flex items-center">
              {liveTranscript ? (
                <p className="text-sm text-text-secondary leading-relaxed">{liveTranscript}</p>
              ) : (
                <p className="text-xs text-text-muted flex items-center gap-2">
                  <span className="w-1.5 h-1.5 bg-primary/60 rounded-full animate-pulse" />
                  Listening — speak now
                </p>
              )}
            </div>
          </div>
        ) : (
          /* ── Normal input state ── */
          <div className="flex gap-2 items-center bg-surface-2 border border-white/[0.07] hover:border-white/[0.12] rounded-xl px-3 py-2.5 transition-colors duration-150">
            <button
              onClick={startRecording}
              aria-label="Start voice input"
              className="w-9 h-9 rounded-lg flex items-center justify-center flex-shrink-0 cursor-pointer transition-colors duration-150 hover:bg-surface-3 text-text-muted hover:text-text-secondary"
            >
              <Mic className="w-4 h-4" />
            </button>

            <input
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={(e) => e.key === "Enter" && !e.shiftKey && sendText(input)}
              placeholder={
                sessionId
                  ? "Ask your AI coach..."
                  : "Select a session above to ask workout-specific questions"
              }
              className="flex-1 bg-transparent text-sm text-text-primary placeholder:text-text-muted outline-none py-1"
            />

            <button
              onClick={() => sendText(input)}
              disabled={!input.trim() || loading}
              aria-label="Send message"
              className="w-9 h-9 rounded-lg bg-primary hover:bg-primary-dim disabled:opacity-30 disabled:cursor-not-allowed flex items-center justify-center flex-shrink-0 cursor-pointer transition-colors duration-150"
            >
              <Send className="w-4 h-4 text-white" />
            </button>
          </div>
        )}
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
