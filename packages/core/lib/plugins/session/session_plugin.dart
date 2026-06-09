import 'dart:async';

import 'package:hightouch_events/analytics.dart';
import 'package:hightouch_events/event.dart';
import 'package:hightouch_events/plugin.dart';
import 'package:hightouch_events/plugins/session/session_plugin_helper.dart';
import 'package:hightouch_events/plugins/session/session_state.dart';
import 'package:hightouch_events/utils/lifecycle/lifecycle.dart';

class SessionPlugin extends PlatformPlugin with Resetable {
  SessionPlugin({int Function()? now})
      : now = now ?? (() => DateTime.now().millisecondsSinceEpoch),
        super(PluginType.enrichment);

  final int Function() now;
  StreamSubscription<AppStatus>? _appStateSubscription;
  bool _isAppInBackground = false;

  @override
  void configure(Analytics analytics) {
    super.configure(analytics);

    if (!SessionPluginHelper.isEnabled(analytics.state.configuration.state)) {
      return;
    }

    _appStateSubscription = lifecycle.listen((nextAppState) {
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
    final result = SessionPluginHelper.processEvent(
      state: await analytics.state.sessionState.state,
      now: currentTime,
      messageId: event.messageId ?? '',
      timestamp: event.timestamp ??
          DateTime.fromMillisecondsSinceEpoch(currentTime, isUtc: true)
              .toIso8601String(),
      foregroundSessionTimeout: config.foregroundSessionTimeout,
      backgroundSessionTimeout: config.backgroundSessionTimeout,
      isAppInBackground: _isAppInBackground,
    );

    analytics.state.sessionState.setState(result.sessionState);
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
    final state = await analytics.state.sessionState.state;
    analytics.state.sessionState.setState(SessionPluginHelper.rotateSession(
      state,
      currentTime,
      '',
      DateTime.fromMillisecondsSinceEpoch(currentTime, isUtc: true)
          .toIso8601String(),
    ));
  }

  Future<void> handleAppStateChange(AppStatus nextAppState) async {
    final analytics = this.analytics;
    if (analytics == null ||
        !SessionPluginHelper.isEnabled(analytics.state.configuration.state)) {
      _isAppInBackground = nextAppState == AppStatus.background;
      return;
    }

    final wasInBackground = _isAppInBackground;
    _isAppInBackground = nextAppState == AppStatus.background;

    if (!wasInBackground && _isAppInBackground) {
      final state = await analytics.state.sessionState.state;
      analytics.state.sessionState
          .setState(SessionPluginHelper.markBackgrounded(state, now()));
    } else if (wasInBackground && !_isAppInBackground) {
      final config = analytics.state.configuration.state;
      final state = await analytics.state.sessionState.state;
      analytics.state.sessionState
          .setState(SessionPluginHelper.markForegrounded(
        state: state,
        now: now(),
        backgroundSessionTimeout: config.backgroundSessionTimeout,
      ));
    }
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
