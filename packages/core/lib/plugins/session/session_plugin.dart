import 'dart:async';

import 'package:hightouch_events/analytics.dart';
import 'package:hightouch_events/event.dart';
import 'package:hightouch_events/plugin.dart';
import 'package:hightouch_events/plugins/session/session_plugin_helper.dart';
import 'package:hightouch_events/plugins/session/session_state.dart';
import 'package:hightouch_events/plugins/session/session_state_coordinator.dart';
import 'package:hightouch_events/utils/lifecycle/lifecycle.dart';

class SessionPlugin extends PlatformPlugin with Resetable {
  SessionPlugin({
    int Function()? now,
    SessionStateCoordinator? sessionStateCoordinator,
  })  : now = now ?? (() => DateTime.now().millisecondsSinceEpoch),
        _sessionStateCoordinator =
            sessionStateCoordinator ?? SessionStateCoordinator(),
        super(PluginType.enrichment);

  final int Function() now;
  final SessionStateCoordinator _sessionStateCoordinator;
  StreamSubscription<AppStatus>? _appStateSubscription;

  @override
  void configure(Analytics analytics) {
    super.configure(analytics);

    if (!SessionPluginHelper.isEnabled(analytics.state.configuration.state)) {
      return;
    }

    _appStateSubscription = analytics.state.listenAppState((nextAppState) {
      unawaited(handleAppStateChange(nextAppState));
    });
  }

  @override
  Future<RawEvent?> execute(RawEvent event) async {
    final analytics = this.analytics;
    if (analytics == null ||
        !SessionPluginHelper.isEnabled(analytics.state.configuration.state)) {
      return event;
    }

    final currentTime = now();
    final config = analytics.state.configuration.state;
    final result = await _sessionStateCoordinator.processEvent(
      sessionStateStore: analytics.state.sessionState,
      config: config,
      now: currentTime,
      messageId: event.messageId ?? '',
      timestamp: event.timestamp ??
          DateTime.fromMillisecondsSinceEpoch(currentTime, isUtc: true)
              .toIso8601String(),
    );

    event.context = _addSessionContext(event.context, result.contextSession);
    return event;
  }

  @override
  Future<void> reset() async {
    final analytics = this.analytics;
    if (analytics == null ||
        !SessionPluginHelper.isEnabled(analytics.state.configuration.state)) {
      return;
    }

    final currentTime = now();
    await _sessionStateCoordinator.rotateOnReset(
      sessionStateStore: analytics.state.sessionState,
      now: currentTime,
      timestamp: DateTime.fromMillisecondsSinceEpoch(currentTime, isUtc: true)
          .toIso8601String(),
    );
  }

  Future<void> handleAppStateChange(AppStatus nextAppState) async {
    final analytics = this.analytics;
    final sessionEnabled = analytics != null &&
        SessionPluginHelper.isEnabled(analytics.state.configuration.state);

    await _sessionStateCoordinator.onAppStateChange(
      nextAppState: nextAppState,
      sessionStateStore: analytics?.state.sessionState,
      config: analytics?.state.configuration.state,
      now: now,
      sessionEnabled: sessionEnabled,
    );
  }

  Context? _addSessionContext(
      Context? eventContext, ContextSession contextSession) {
    if (eventContext == null) {
      return eventContext;
    }

    final context = Context(
      eventContext.app,
      eventContext.device,
      eventContext.library,
      eventContext.locale,
      eventContext.network,
      eventContext.os,
      eventContext.screen,
      eventContext.timezone,
      eventContext.traits,
      instanceId: eventContext.instanceId,
      custom: Map<String, dynamic>.from(eventContext.custom),
    );

    context.custom.remove('sessionStart');
    context.custom['session'] = contextSession.toJson();
    context.custom['sessionId'] = contextSession.sessionId;
    if (contextSession.sessionStart == true) {
      context.custom['sessionStart'] = true;
    }

    return context;
  }

  @override
  void shutdown() {
    _cancelAppStateSubscription();
    super.shutdown();
  }

  @override
  void clear() {
    _cancelAppStateSubscription();
    super.clear();
  }

  void _cancelAppStateSubscription() {
    unawaited(_appStateSubscription?.cancel());
    _appStateSubscription = null;
  }
}
