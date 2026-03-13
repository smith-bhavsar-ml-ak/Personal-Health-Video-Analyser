import type { SessionResult, SessionSummary, VoiceQueryRequest, VoiceQueryResponse } from "./types";
import { getToken, setToken, clearToken } from "./auth";

const BASE =
  typeof window === "undefined"
    ? (process.env.API_URL ?? "http://localhost:8000")
    : (process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8000");

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const token = getToken();
  const headers: Record<string, string> = {
    ...(init?.headers as Record<string, string>),
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
  };

  const res = await fetch(`${BASE}/api/v1${path}`, { ...init, headers });

  if (res.status === 401) {
    clearToken();
    window.location.href = "/login";
    throw new Error("Session expired. Please log in again.");
  }

  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err?.detail ?? `Request failed: ${res.status}`);
  }

  if (res.status === 204) return undefined as T;
  return res.json();
}

export const api = {
  // ── Auth ─────────────────────────────────────────────────────────────────────
  async register(email: string, password: string): Promise<{ access_token: string; email: string }> {
    const data = await request<{ access_token: string; email: string }>("/auth/register", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password }),
    });
    setToken(data.access_token);
    return data;
  },

  async login(email: string, password: string): Promise<{ access_token: string; email: string }> {
    const data = await request<{ access_token: string; email: string }>("/auth/login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password }),
    });
    setToken(data.access_token);
    return data;
  },

  async getMe(): Promise<{ user_id: string; email: string }> {
    return request<{ user_id: string; email: string }>("/auth/me");
  },

  logout(): void {
    clearToken();
    window.location.href = "/login";
  },

  // ── Sessions ──────────────────────────────────────────────────────────────────
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
