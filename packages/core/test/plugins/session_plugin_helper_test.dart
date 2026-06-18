import 'package:flutter_test/flutter_test.dart';
import 'package:hightouch_events/plugins/session/session_plugin_helper.dart';
import 'package:hightouch_events/plugins/session/session_state.dart';
import 'package:hightouch_events/state.dart';

void main() {
  final initialState = SessionState(
    sessionId: 1000,
    sessionIndex: 0,
    previousSessionId: null,
    firstEventId: 'first-message-id',
    firstEventTimestamp: '2026-01-01T00:00:01.000Z',
    eventIndex: 1,
    lastActivityAt: 1000,
    backgroundedAt: null,
  );

  group('SessionPluginHelper', () {
    test('creates the first session on the first event', () {
      final result = SessionPluginHelper.processEvent(
        state: null,
        now: 1000,
        messageId: 'message-id',
        timestamp: '2026-01-01T00:00:01.000Z',
        foregroundSessionTimeout: 1800000,
        backgroundSessionTimeout: 1800000,
      );

      expect(result.contextSession.toJson(), {
        'sessionId': 1000,
        'sessionIndex': 0,
        'sessionStart': true,
        'eventIndex': 0,
        'previousSessionId': null,
        'firstEventId': 'message-id',
        'firstEventTimestamp': '2026-01-01T00:00:01.000Z',
      });
      expect(result.sessionState.toJson(), {
        'sessionId': 1000,
        'sessionIndex': 0,
        'previousSessionId': null,
        'firstEventId': 'message-id',
        'firstEventTimestamp': '2026-01-01T00:00:01.000Z',
        'eventIndex': 1,
        'lastActivityAt': 1000,
        'backgroundedAt': null,
      });
    });

    test('increments the event index within the same session', () {
      final result = SessionPluginHelper.processEvent(
        state: initialState,
        now: 2000,
        messageId: 'second-message-id',
        timestamp: '2026-01-01T00:00:02.000Z',
        foregroundSessionTimeout: 1800000,
        backgroundSessionTimeout: 1800000,
      );

      expect(result.contextSession.toJson(), {
        'sessionId': 1000,
        'sessionIndex': 0,
        'eventIndex': 1,
        'previousSessionId': null,
        'firstEventId': 'first-message-id',
        'firstEventTimestamp': '2026-01-01T00:00:01.000Z',
      });
      expect(result.sessionState.eventIndex, 2);
      expect(result.sessionState.lastActivityAt, 2000);
    });

    test('rotates after foreground inactivity exceeds the configured timeout',
        () {
      final result = SessionPluginHelper.processEvent(
        state: initialState,
        now: 3000,
        messageId: 'new-session-message-id',
        timestamp: '2026-01-01T00:00:03.000Z',
        foregroundSessionTimeout: 1999,
        backgroundSessionTimeout: 1800000,
      );

      expect(result.contextSession.toJson(), {
        'sessionId': 3000,
        'sessionIndex': 1,
        'sessionStart': true,
        'eventIndex': 0,
        'previousSessionId': 1000,
        'firstEventId': 'new-session-message-id',
        'firstEventTimestamp': '2026-01-01T00:00:03.000Z',
      });
    });

    test('rotates on the first event after a long background duration', () {
      final backgroundedState = initialState.copyWith(backgroundedAt: 1500);
      final foregroundedState = SessionPluginHelper.markForegrounded(
        state: backgroundedState,
        now: 4000,
        backgroundSessionTimeout: 2000,
      );

      final result = SessionPluginHelper.processEvent(
        state: foregroundedState,
        now: 4000,
        messageId: 'foreground-message-id',
        timestamp: '2026-01-01T00:00:04.000Z',
        foregroundSessionTimeout: 1800000,
        backgroundSessionTimeout: 2000,
      );

      expect(result.contextSession.toJson(), {
        'sessionId': 4000,
        'sessionIndex': 1,
        'sessionStart': true,
        'eventIndex': 0,
        'previousSessionId': 1000,
        'firstEventId': 'foreground-message-id',
        'firstEventTimestamp': '2026-01-01T00:00:04.000Z',
      });
    });

    test('preserves backgroundedAt when re-backgrounding with pending rotation',
        () {
      final backgroundedState = initialState.copyWith(backgroundedAt: 1500);
      final foregroundedState = SessionPluginHelper.markForegrounded(
        state: backgroundedState,
        now: 4000,
        backgroundSessionTimeout: 2000,
      );

      expect(foregroundedState?.backgroundedAt, 1500);

      final rebackgroundedState = SessionPluginHelper.markBackgrounded(
        foregroundedState,
        5100,
      );

      expect(rebackgroundedState?.backgroundedAt, 1500);

      final result = SessionPluginHelper.processEvent(
        state: rebackgroundedState,
        now: 5200,
        messageId: 'delayed-rotation-message-id',
        timestamp: '2026-01-01T00:00:05.200Z',
        foregroundSessionTimeout: 1800000,
        backgroundSessionTimeout: 2000,
      );

      expect(result.contextSession.toJson(), {
        'sessionId': 5200,
        'sessionIndex': 1,
        'sessionStart': true,
        'eventIndex': 0,
        'previousSessionId': 1000,
        'firstEventId': 'delayed-rotation-message-id',
        'firstEventTimestamp': '2026-01-01T00:00:05.200Z',
      });
    });

    test(
        'rotates when background timeout exceeded before lifecycle marks foreground',
        () {
      final backgroundedState = initialState.copyWith(backgroundedAt: 1500);

      final result = SessionPluginHelper.processEvent(
        state: backgroundedState,
        now: 4000,
        messageId: 'foreground-message-id',
        timestamp: '2026-01-01T00:00:04.000Z',
        foregroundSessionTimeout: 1800000,
        backgroundSessionTimeout: 2000,
        isAppInBackground: true,
      );

      expect(result.contextSession.toJson(), {
        'sessionId': 4000,
        'sessionIndex': 1,
        'sessionStart': true,
        'eventIndex': 0,
        'previousSessionId': 1000,
        'firstEventId': 'foreground-message-id',
        'firstEventTimestamp': '2026-01-01T00:00:04.000Z',
      });
    });

    test(
        'rotates on cold start when persisted background duration exceeded timeout',
        () {
      final result = SessionPluginHelper.processEvent(
        state: initialState.copyWith(backgroundedAt: 1500),
        now: 4000,
        messageId: 'cold-start-message-id',
        timestamp: '2026-01-01T00:00:04.000Z',
        foregroundSessionTimeout: 1800000,
        backgroundSessionTimeout: 2000,
      );

      expect(result.contextSession.sessionId, 4000);
      expect(result.contextSession.sessionIndex, 1);
      expect(result.contextSession.previousSessionId, 1000);
      expect(result.contextSession.firstEventId, 'cold-start-message-id');
    });

    test('rejects negative session timeouts', () {
      expect(
        () => SessionPluginHelper.validateSessionTimeouts(Configuration(
          'write-key',
          foregroundSessionTimeout: -1,
        )),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => SessionPluginHelper.validateSessionTimeouts(Configuration(
          'write-key',
          backgroundSessionTimeout: -1,
        )),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
