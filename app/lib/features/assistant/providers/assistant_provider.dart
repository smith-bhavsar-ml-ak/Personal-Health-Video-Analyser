import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../core/api/api_service.dart';
import '../../../core/models/session_summary.dart';
import '../../../core/models/voice_query.dart';
import '../../../core/utils/audio_helper.dart';

class ChatMessage {
  final bool isUser;
  final String text;
  const ChatMessage({required this.isUser, required this.text});
}

class AssistantState {
  final List<SessionSummary> sessions;
  final List<SessionSummary> todaySessions;
  final String? autoSessionId;
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isRecording;
  final bool isPlayingAudio;
  final double amplitude; // 0–1, for waveform UI
  final String? error;

  const AssistantState({
    this.sessions        = const [],
    this.todaySessions   = const [],
    this.autoSessionId,
    this.messages        = const [],
    this.isLoading       = false,
    this.isRecording     = false,
    this.isPlayingAudio  = false,
    this.amplitude       = 0,
    this.error,
  });

  List<String> get todayExercises => todaySessions
      .expand((s) => s.exerciseTypes)
      .toSet()
      .toList();

  SessionSummary? get activeSession =>
      sessions.where((s) => s.id == autoSessionId).firstOrNull;

  AssistantState copyWith({
    List<SessionSummary>? sessions,
    List<SessionSummary>? todaySessions,
    String? autoSessionId,
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isRecording,
    bool? isPlayingAudio,
    double? amplitude,
    String? error,
    bool clearError = false,
  }) =>
      AssistantState(
        sessions:       sessions       ?? this.sessions,
        todaySessions:  todaySessions  ?? this.todaySessions,
        autoSessionId:  autoSessionId  ?? this.autoSessionId,
        messages:       messages       ?? this.messages,
        isLoading:      isLoading      ?? this.isLoading,
        isRecording:    isRecording    ?? this.isRecording,
        isPlayingAudio: isPlayingAudio ?? this.isPlayingAudio,
        amplitude:      amplitude      ?? this.amplitude,
        error:          clearError ? null : (error ?? this.error),
      );
}

class AssistantNotifier extends StateNotifier<AssistantState> {
  AssistantNotifier() : super(const AssistantState()) {
    _loadSessions();
    _audioPlayer.onPlayerStateChanged.listen((ps) {
      if (ps == PlayerState.completed || ps == PlayerState.stopped) {
        if (mounted && state.isPlayingAudio) {
          state = state.copyWith(isPlayingAudio: false);
        }
      }
    });
  }

  final _recorder    = AudioRecorder();
  final _audioPlayer = AudioPlayer();

  Timer?    _vadTimer;
  DateTime? _lastSoundAt;

  static const _silenceThresholdDb = -40.0;
  static const _silenceDurationMs  = 1800;

  @override
  void dispose() {
    _vadTimer?.cancel();
    _recorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ── Session loading ────────────────────────────────────────────────────────

  Future<void> _loadSessions() async {
    try {
      final all       = await ApiService.instance.listSessions();
      final completed = all.where((s) => s.isCompleted).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final todaySessions = _sessionsOnLatestDay(completed);
      state = state.copyWith(
        sessions:      completed,
        todaySessions: todaySessions,
        autoSessionId: todaySessions.isNotEmpty
            ? todaySessions.first.id
            : (completed.isNotEmpty ? completed.first.id : null),
      );
    } on Exception catch (_) {}
  }

  List<SessionSummary> _sessionsOnLatestDay(List<SessionSummary> sorted) {
    if (sorted.isEmpty) return [];
    final latestDt = DateTime.tryParse(sorted.first.createdAt);
    if (latestDt == null) return [sorted.first];
    return sorted.where((s) {
      final d = DateTime.tryParse(s.createdAt);
      return d != null &&
          d.year  == latestDt.year &&
          d.month == latestDt.month &&
          d.day   == latestDt.day;
    }).toList();
  }

  // ── Context helpers ────────────────────────────────────────────────────────

  /// Builds a detailed context prefix from ALL of today's sessions so the LLM
  /// knows every exercise done even when we route the API call to one session.
  /// Format: "Today's workout: squat (12 reps, 78% form); jumping_jack (25 reps, 100% form). "
  String _contextPrefix() {
    final today = state.todaySessions;
    if (today.isEmpty) return '';

    // Single session with one exercise type → no prefix needed;
    // the session's own exercise_sets already contain the data.
    if (today.length == 1 && today.first.exerciseTypes.length == 1) return '';

    final parts = today.map((s) {
      final exNames = s.exerciseTypes.join('+');
      final score   = (s.avgFormScore * 100).round();
      return '$exNames (${s.totalReps} reps, $score% form)';
    }).join('; ');

    return "Today's full workout: $parts. ";
  }

  String _withContextPrefix(String query) => _contextPrefix() + query;

  /// Strip the context prefix from a returned query_text (Whisper output
  /// will NOT have the prefix — the backend prepends it — so this is only
  /// needed when we display the query_text back to the user).
  String _stripContextPrefix(String text) {
    final prefix = _contextPrefix();
    if (prefix.isNotEmpty && text.startsWith(prefix)) {
      return text.substring(prefix.length).trim();
    }
    return text;
  }

  // ── Greeting / small-talk detection ───────────────────────────────────────

  /// Returns true when the message is pure social/conversational — no workout
  /// context prefix should be added so the LLM responds naturally and briefly.
  static bool _isSmallTalk(String lower) {
    const patterns = [
      'hi', 'hello', 'hey', 'hiya', 'howdy',
      'thank', 'thanks', 'thank you', 'cheers', 'appreciate',
      'bye', 'goodbye', 'see you', 'later', 'cya',
      'good morning', 'good afternoon', 'good evening', 'good night',
      'how are you', 'how r u', "what's up", 'sup',
      'great', 'awesome', 'nice', 'cool', 'perfect',
      'ok', 'okay', 'got it', 'sounds good', 'sure',
      'welcome', 'no problem', 'np',
    ];
    // Match only when the entire trimmed message is small-talk
    // (short message ≤ 6 words and contains a pattern)
    final wordCount = lower.trim().split(RegExp(r'\s+')).length;
    if (wordCount > 6) return false;
    return patterns.any((p) =>
        lower == p || lower.startsWith('$p ') || lower.endsWith(' $p') ||
        lower.contains(' $p '));
  }

  // ── Smart session resolution ───────────────────────────────────────────────

  String? _resolveSession(String query) {
    if (state.sessions.isEmpty) return null;
    final lower = query.toLowerCase();

    const exerciseKeywords = <String, String>{
      'squat':        'squat',
      'lunge':        'lunge',
      'bicep curl':   'bicep_curl',
      'bicep':        'bicep_curl',
      'curl':         'bicep_curl',
      'jumping jack': 'jumping_jack',
      'jumping':      'jumping_jack',
      'plank':        'plank',
    };

    final sortedKeys = exerciseKeywords.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final keyword in sortedKeys) {
      if (lower.contains(keyword)) {
        final type  = exerciseKeywords[keyword]!;
        final today = state.todaySessions
            .where((s) => s.exerciseTypes.contains(type))
            .firstOrNull;
        if (today != null) return today.id;
        return state.sessions
            .firstWhere(
              (s) => s.exerciseTypes.contains(type),
              orElse: () => state.sessions.first,
            )
            .id;
      }
    }

    return state.todaySessions.isNotEmpty
        ? state.todaySessions.first.id
        : state.sessions.first.id;
  }

  // ── Public actions ─────────────────────────────────────────────────────────

  Future<void> sendText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (state.sessions.isEmpty) {
      state = state.copyWith(
          error: 'No completed sessions yet. Analyze a video first.');
      return;
    }
    final sessionId = _resolveSession(trimmed);
    if (sessionId == null) return;
    if (sessionId != state.autoSessionId) {
      state = state.copyWith(autoSessionId: sessionId);
    }
    _appendUser(trimmed);
    // Skip workout context prefix for greetings / small-talk so the LLM
    // responds naturally ("You're welcome!") instead of giving form feedback.
    final query = _isSmallTalk(trimmed.toLowerCase())
        ? trimmed
        : _withContextPrefix(trimmed);
    await _callApi(sessionId, VoiceQueryRequest(queryText: query));
  }

  Future<void> toggleRecording() async {
    if (state.isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  void clearConversation() =>
      state = state.copyWith(messages: const [], clearError: true);

  // ── Recording ─────────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    // Unlock Web Audio API during this user gesture so TTS can play later.
    unlockWebAudio();

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      state = state.copyWith(error: 'Microphone permission denied.');
      return;
    }

    final path = kIsWeb
        ? 'voice_query.wav'
        : '${(await getTemporaryDirectory()).path}/voice_query.wav';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000),
      path: path,
    );
    state = state.copyWith(isRecording: true, amplitude: 0, clearError: true);
    _startVAD();
  }

  void _startVAD() {
    _lastSoundAt = DateTime.now();
    _vadTimer?.cancel();
    _vadTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) async {
      if (!mounted || !state.isRecording) { timer.cancel(); return; }
      try {
        final amp  = await _recorder.getAmplitude();
        final db   = amp.current;
        final norm = ((db + 60) / 60).clamp(0.0, 1.0);
        if (mounted) state = state.copyWith(amplitude: norm);

        if (db > _silenceThresholdDb) {
          _lastSoundAt = DateTime.now();
        } else {
          final silenceMs =
              DateTime.now().difference(_lastSoundAt!).inMilliseconds;
          if (silenceMs >= _silenceDurationMs) {
            timer.cancel();
            await _stopRecording();
          }
        }
      } catch (_) {
        // Amplitude unavailable on some browsers — VAD disabled
      }
    });
  }

  Future<void> _stopRecording() async {
    _vadTimer?.cancel();
    final path = await _recorder.stop();
    if (!mounted) return;
    state = state.copyWith(isRecording: false, amplitude: 0);
    if (path == null) return;

    final Uint8List bytes;
    try {
      bytes = await fetchAudioBytes(path);
    } on Exception {
      state = state.copyWith(error: 'Could not read recorded audio.');
      return;
    }
    if (bytes.isEmpty) return;

    final sessionId = _resolveSession('');
    if (sessionId == null) return;

    // Add a placeholder — replaced with real transcription after API response
    final placeholderIdx = state.messages.length;
    _appendUser('🎤 …');

    await _callApi(
      sessionId,
      VoiceQueryRequest(
        audioB64:  base64Encode(bytes),
        queryText: _contextPrefix(), // context prefix; audio is the actual query
      ),
      voicePlaceholderIdx: placeholderIdx,
    );
  }

  // ── API call + audio playback ──────────────────────────────────────────────

  void _appendUser(String text) {
    state = state.copyWith(
      messages: [...state.messages, ChatMessage(isUser: true, text: text)],
    );
  }

  Future<void> _callApi(
    String sessionId,
    VoiceQueryRequest request, {
    int? voicePlaceholderIdx, // index of "🎤 …" placeholder to replace
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final resp = await ApiService.instance.voiceQuery(sessionId, request);
      if (!mounted) return;

      // Build updated message list
      var msgs = [...state.messages];

      // Replace voice placeholder with the actual transcription
      if (voicePlaceholderIdx != null &&
          voicePlaceholderIdx < msgs.length &&
          msgs[voicePlaceholderIdx].isUser) {
        final transcribed = _stripContextPrefix(resp.queryText);
        msgs[voicePlaceholderIdx] =
            ChatMessage(isUser: true, text: '🎤 $transcribed');
      }

      state = state.copyWith(
        isLoading: false,
        messages:  [...msgs, ChatMessage(isUser: false, text: resp.responseText)],
      );

      // Play TTS response
      if (resp.audioB64 != null) {
        final audioBytes = base64Decode(resp.audioB64!);
        if (!mounted) return;
        state = state.copyWith(isPlayingAudio: true);
        if (kIsWeb) {
          await playAudioBytesOnWeb(audioBytes);
          // AudioContext plays asynchronously; give it a moment before clearing flag
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) state = state.copyWith(isPlayingAudio: false);
        } else {
          await _audioPlayer.play(BytesSource(audioBytes));
          // isPlayingAudio cleared by onPlayerStateChanged listener
        }
      }
    } on Exception catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error:     'Failed to get response: $e',
        messages:  [
          ...state.messages,
          const ChatMessage(
              isUser: false,
              text:   'Sorry, something went wrong. Please try again.'),
        ],
      );
    }
  }
}

final assistantProvider =
    StateNotifierProvider.autoDispose<AssistantNotifier, AssistantState>(
  (_) => AssistantNotifier(),
);
