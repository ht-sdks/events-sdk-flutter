import 'dart:async';

import 'package:hightouch_events/plugins/session/session_plugin_helper.dart';
import 'package:hightouch_events/plugins/session/session_state.dart';
import 'package:hightouch_events/state.dart';
import 'package:hightouch_events/utils/lifecycle/lifecycle.dart';
import 'package:hightouch_events/utils/queue.dart';

typedef SessionStateReadHook = Future<void> Function(SessionState? state);
typedef SessionStateResetHook = Future<void> Function();

class SessionStateCoordinator {
  SessionStateCoordinator({
    ConcurrencyQueue<dynamic>? queue,
    SessionStateReadHook? afterRead,
    SessionStateResetHook? beforeRotateOnReset,
  })  : _queue = queue ?? ConcurrencyQueue(),
        _afterRead = afterRead ?? _noopAfterRead,
        _beforeRotateOnReset = beforeRotateOnReset ?? _noopBeforeRotateOnReset;

  static Future<void> _noopAfterRead(SessionState? _) async {}
  static Future<void> _noopBeforeRotateOnReset() async {}

  final ConcurrencyQueue<dynamic> _queue;
  final SessionStateReadHook _afterRead;
  final SessionStateResetHook _beforeRotateOnReset;
  Completer<void>? _pendingReset;

  Future<void> _awaitPendingReset() async {
    final pendingReset = _pendingReset;
    if (pendingReset != null) {
      await pendingReset.future;
    }
  }

  void _beginReset() {
    _pendingReset ??= Completer<void>();
  }

  void _completeReset() {
    final pendingReset = _pendingReset;
    if (pendingReset != null && !pendingReset.isCompleted) {
      pendingReset.complete();
    }
    _pendingReset = null;
  }
  bool isAppInBackground = false;

  Future<EnrichedSessionEvent> processEvent({
    required SessionStateState sessionStateStore,
    required Configuration config,
    required int now,
    required String messageId,
    required String timestamp,
  }) async {
    while (true) {
      final result = await _queue.enqueue(() async {
        await _awaitPendingReset();
        final sessionState = await sessionStateStore.state;
        await _afterRead(sessionState);
        if (_pendingReset != null) {
          return null;
        }
        final enrichedEvent = SessionPluginHelper.processEvent(
          state: sessionState,
          now: now,
          messageId: messageId,
          timestamp: timestamp,
          foregroundSessionTimeout: config.foregroundSessionTimeout,
          backgroundSessionTimeout: config.backgroundSessionTimeout,
          isAppInBackground: isAppInBackground,
        );
        sessionStateStore.setState(enrichedEvent.sessionState);
        return enrichedEvent;
      });

      if (result != null) {
        return result as EnrichedSessionEvent;
      }
    }
  }

  Future<void> rotateOnReset({
    required SessionStateState sessionStateStore,
    required int now,
    required String timestamp,
  }) {
    _beginReset();
    return _queue.enqueue(() async {
      try {
        await _beforeRotateOnReset();
        final state = await sessionStateStore.state;
        sessionStateStore.setState(SessionPluginHelper.rotateSession(
          state,
          now,
          '',
          timestamp,
        ));
      } finally {
        _completeReset();
      }
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
