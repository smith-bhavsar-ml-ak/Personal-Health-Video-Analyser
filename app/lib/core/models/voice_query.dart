class VoiceQuery {
  final String id;
  final String queryText;
  final String responseText;
  final String createdAt;

  const VoiceQuery({
    required this.id,
    required this.queryText,
    required this.responseText,
    required this.createdAt,
  });

  factory VoiceQuery.fromJson(Map<String, dynamic> json) => VoiceQuery(
        id:           json['id']            as String,
        queryText:    json['query_text']    as String,
        responseText: json['response_text'] as String,
        createdAt:    json['created_at']    as String,
      );
}

class VoiceQueryRequest {
  final String? queryText;
  final String? audioB64;
  final String? profileContext;

  const VoiceQueryRequest({this.queryText, this.audioB64, this.profileContext});

  Map<String, dynamic> toJson() => {
        if (queryText       != null) 'query_text':       queryText,
        if (audioB64        != null) 'audio_b64':        audioB64,
        if (profileContext  != null) 'profile_context':  profileContext,
      };
}

class VoiceQueryResponse {
  final String queryText;
  final String responseText;
  final String? audioB64;

  const VoiceQueryResponse({
    required this.queryText,
    required this.responseText,
    this.audioB64,
  });

  factory VoiceQueryResponse.fromJson(Map<String, dynamic> json) => VoiceQueryResponse(
        queryText:    json['query_text']    as String,
        responseText: json['response_text'] as String,
        audioB64:     json['audio_b64']     as String?,
      );
}
