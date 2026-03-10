import type { SessionResult, SessionSummary, VoiceQueryRequest, VoiceQueryResponse } from "./types";

const BASE = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8000";

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${BASE}/api/v1${path}`, init);
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err?.detail ?? `Request failed: ${res.status}`);
  }
  return res.json();
}

export const api = {
  async analyzeVideo(file: File): Promise<SessionResult> {
    const form = new FormData();
    form.append("video", file);
    return request<SessionResult>("/sessions/analyze", { method: "POST", body: form });
  },

  async listSessions(): Promise<SessionSummary[]> {
    return request<SessionSummary[]>("/sessions");
  },

  async getSession(id: string): Promise<SessionResult> {
    return request<SessionResult>(`/sessions/${id}`);
  },

  async deleteSession(id: string): Promise<void> {
    await request(`/sessions/${id}`, { method: "DELETE" });
  },

  async voiceQuery(sessionId: string, body: VoiceQueryRequest): Promise<VoiceQueryResponse> {
    return request<VoiceQueryResponse>(`/sessions/${sessionId}/voice`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
  },
};
