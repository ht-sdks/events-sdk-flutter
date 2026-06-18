import 'package:hightouch_events/plugins/session/session_state.dart';
import 'package:hightouch_events/state.dart';

class EnrichedSessionEvent {
  final ContextSession contextSession;
  final SessionState sessionState;

  EnrichedSessionEvent({
    required this.contextSession,
    required this.sessionState,
  });
}

class SessionPluginHelper {
  static void validateSessionTimeouts(Configuration config) {
    if (config.foregroundSessionTimeout < 0) {
      throw ArgumentError(
        'foregroundSessionTimeout must be greater than or equal to zero.',
      );
    }
    if (config.backgroundSessionTimeout < 0) {
      throw ArgumentError(
        'backgroundSessionTimeout must be greater than or equal to zero.',
      );
    }
  }

  static bool isEnabled(Configuration config) {
    return !(config.foregroundSessionTimeout == 0 &&
        config.backgroundSessionTimeout == 0);
  }

  static bool shouldRotateOnResume(
    SessionState? state,
    int now, {
    int backgroundSessionTimeout = 0,
  }) {
    if (state?.backgroundedAt == null || backgroundSessionTimeout <= 0) {
      return false;
    }

    return now - state!.backgroundedAt! > backgroundSessionTimeout;
  }

  static bool shouldRotateOnInactivity(
    SessionState? state,
    int now, {
    int foregroundSessionTimeout = 0,
  }) {
    if (state == null || foregroundSessionTimeout <= 0) {
      return false;
    }

    return now - state.lastActivityAt > foregroundSessionTimeout;
  }

  static SessionState rotateSession(
    SessionState? state,
    int now,
    String firstEventId,
    String firstEventTimestamp,
  ) {
    return SessionState(
      sessionId: now,
      sessionIndex: state == null ? 0 : state.sessionIndex + 1,
      previousSessionId: state?.sessionId,
      firstEventId: firstEventId,
      firstEventTimestamp: firstEventTimestamp,
      eventIndex: 0,
      lastActivityAt: now,
      backgroundedAt: null,
    );
  }

  static EnrichedSessionEvent enrichEvent(
    SessionState state,
    int now, {
    bool updateActivity = true,
  }) {
    final sessionStart = state.eventIndex == 0;
    final contextSession = ContextSession(
      sessionId: state.sessionId,
      sessionIndex: state.sessionIndex,
      sessionStart: sessionStart ? true : null,
      eventIndex: state.eventIndex,
      previousSessionId: state.previousSessionId,
      firstEventId: state.firstEventId,
      firstEventTimestamp: state.firstEventTimestamp,
    );

    final sessionState = state.copyWith(
      eventIndex: state.eventIndex + 1,
      lastActivityAt: updateActivity ? now : state.lastActivityAt,
      clearBackgroundedAt: updateActivity,
    );

    return EnrichedSessionEvent(
      contextSession: contextSession,
      sessionState: sessionState,
    );
  }

  static SessionState ensureFirstEvent(
    SessionState state,
    String messageId,
    String timestamp,
  ) {
    if (state.eventIndex != 0 || state.firstEventId != '') {
      return state;
    }

    return state.copyWith(
      firstEventId: messageId,
      firstEventTimestamp: timestamp,
    );
  }

  static EnrichedSessionEvent processEvent({
    required SessionState? state,
    required int now,
    required String messageId,
    required String timestamp,
    int foregroundSessionTimeout = 0,
    int backgroundSessionTimeout = 0,
    bool isAppInBackground = false,
  }) {
    final shouldRotate = state == null ||
        shouldRotateOnResume(
          state,
          now,
          backgroundSessionTimeout: backgroundSessionTimeout,
        ) ||
        (!isAppInBackground &&
            shouldRotateOnInactivity(
              state,
              now,
              foregroundSessionTimeout: foregroundSessionTimeout,
            ));

    final currentState = shouldRotate
        ? rotateSession(state, now, messageId, timestamp)
        : ensureFirstEvent(state, messageId, timestamp);

    return enrichEvent(
      currentState,
      now,
      updateActivity: !isAppInBackground,
    );
  }

  static SessionState? markBackgrounded(SessionState? state, int now) {
    if (state == null) {
      return state;
    }

    return state.copyWith(backgroundedAt: state.backgroundedAt ?? now);
  }

  static SessionState? markForegrounded({
    required SessionState? state,
    required int now,
    int backgroundSessionTimeout = 0,
  }) {
    if (state == null) {
      return state;
    }

    if (shouldRotateOnResume(
      state,
      now,
      backgroundSessionTimeout: backgroundSessionTimeout,
    )) {
      return state;
    }

    return state.copyWith(
      lastActivityAt: now,
      clearBackgroundedAt: true,
    );
  }
}
