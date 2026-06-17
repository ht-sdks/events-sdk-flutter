import 'package:hightouch_events/plugins/session/session_plugin_helper.dart';
import 'package:hightouch_events/plugins/session/session_state.dart';
import 'package:hightouch_events/state.dart';
import 'package:hightouch_events/utils/lifecycle/lifecycle.dart';
import 'package:hightouch_events/utils/queue.dart';

typedef SessionStateReadHook = Future<void> Function(SessionState? state);

class SessionStateCoordinator {
  SessionStateCoordinator({
    ConcurrencyQueue<dynamic>? queue,
    SessionStateReadHook? afterRead,
  })  : _queue = queue ?? ConcurrencyQueue(),
        _afterRead = afterRead ?? _noopAfterRead;

  static Future<void> _noopAfterRead(SessionState? _) async {}

  final ConcurrencyQueue<dynamic> _queue;
  final SessionStateReadHook _afterRead;
  bool isAppInBackground = false;

  Future<EnrichedSessionEvent> processEvent({
    required SessionStateState sessionStateStore,
    required Configuration config,
    required int now,
    required String messageId,
    required String timestamp,
  }) async {
    return await _queue.enqueue(() async {
      final sessionState = await sessionStateStore.state;
      await _afterRead(sessionState);
      final result = SessionPluginHelper.processEvent(
        state: sessionState,
        now: now,
        messageId: messageId,
        timestamp: timestamp,
        foregroundSessionTimeout: config.foregroundSessionTimeout,
        backgroundSessionTimeout: config.backgroundSessionTimeout,
        isAppInBackground: isAppInBackground,
      );
      sessionStateStore.setState(result.sessionState);
      return result;
    }) as EnrichedSessionEvent;
  }

  Future<void> rotateOnReset({
    required SessionStateState sessionStateStore,
    required int now,
    required String timestamp,
  }) {
    return _queue.enqueue(() async {
      final state = await sessionStateStore.state;
      sessionStateStore.setState(SessionPluginHelper.rotateSession(
        state,
        now,
        '',
        timestamp,
      ));
    });
  }

  Future<void> onAppStateChange({
    required AppStatus nextAppState,
    SessionStateState? sessionStateStore,
    Configuration? config,
    required int Function() now,
    required bool sessionEnabled,
  }) {
    return _queue.enqueue(() async {
      if (!sessionEnabled) {
        isAppInBackground = nextAppState == AppStatus.background;
        return;
      }

      final wasInBackground = isAppInBackground;
      isAppInBackground = nextAppState == AppStatus.background;

      if (!wasInBackground && isAppInBackground) {
        final state = await sessionStateStore!.state;
        sessionStateStore.setState(
            SessionPluginHelper.markBackgrounded(state, now()));
      } else if (wasInBackground && !isAppInBackground) {
        final state = await sessionStateStore!.state;
        sessionStateStore.setState(SessionPluginHelper.markForegrounded(
          state: state,
          now: now(),
          backgroundSessionTimeout: config!.backgroundSessionTimeout,
        ));
      }
    });
  }
}
