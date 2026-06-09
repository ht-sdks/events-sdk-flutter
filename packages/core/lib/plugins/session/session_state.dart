class SessionState {
  final int sessionId;
  final int sessionIndex;
  final int? previousSessionId;
  final String firstEventId;
  final String firstEventTimestamp;
  final int eventIndex;
  final int lastActivityAt;
  final int? backgroundedAt;

  SessionState({
    required this.sessionId,
    required this.sessionIndex,
    required this.previousSessionId,
    required this.firstEventId,
    required this.firstEventTimestamp,
    required this.eventIndex,
    required this.lastActivityAt,
    required this.backgroundedAt,
  });

  factory SessionState.fromJson(Map<String, dynamic> json) {
    return SessionState(
      sessionId: _asInt(json['sessionId']) ?? 0,
      sessionIndex: _asInt(json['sessionIndex']) ?? 0,
      previousSessionId: _asInt(json['previousSessionId']),
      firstEventId: json['firstEventId'] as String? ?? '',
      firstEventTimestamp: json['firstEventTimestamp'] as String? ?? '',
      eventIndex: _asInt(json['eventIndex']) ?? 0,
      lastActivityAt: _asInt(json['lastActivityAt']) ?? 0,
      backgroundedAt: _asInt(json['backgroundedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'sessionIndex': sessionIndex,
      'previousSessionId': previousSessionId,
      'firstEventId': firstEventId,
      'firstEventTimestamp': firstEventTimestamp,
      'eventIndex': eventIndex,
      'lastActivityAt': lastActivityAt,
      'backgroundedAt': backgroundedAt,
    };
  }

  SessionState copyWith({
    int? sessionId,
    int? sessionIndex,
    int? previousSessionId,
    bool clearPreviousSessionId = false,
    String? firstEventId,
    String? firstEventTimestamp,
    int? eventIndex,
    int? lastActivityAt,
    int? backgroundedAt,
    bool clearBackgroundedAt = false,
  }) {
    return SessionState(
      sessionId: sessionId ?? this.sessionId,
      sessionIndex: sessionIndex ?? this.sessionIndex,
      previousSessionId: clearPreviousSessionId
          ? null
          : previousSessionId ?? this.previousSessionId,
      firstEventId: firstEventId ?? this.firstEventId,
      firstEventTimestamp: firstEventTimestamp ?? this.firstEventTimestamp,
      eventIndex: eventIndex ?? this.eventIndex,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      backgroundedAt:
          clearBackgroundedAt ? null : backgroundedAt ?? this.backgroundedAt,
    );
  }
}

class ContextSession {
  final int sessionId;
  final int sessionIndex;
  final bool? sessionStart;
  final int eventIndex;
  final int? previousSessionId;
  final String firstEventId;
  final String firstEventTimestamp;

  ContextSession({
    required this.sessionId,
    required this.sessionIndex,
    required this.sessionStart,
    required this.eventIndex,
    required this.previousSessionId,
    required this.firstEventId,
    required this.firstEventTimestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'sessionIndex': sessionIndex,
      if (sessionStart == true) 'sessionStart': true,
      'eventIndex': eventIndex,
      'previousSessionId': previousSessionId,
      'firstEventId': firstEventId,
      'firstEventTimestamp': firstEventTimestamp,
    };
  }
}

int? _asInt(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}
