import 'dart:async';

import 'package:hightouch_events/analytics.dart';
import 'package:hightouch_events/event.dart';
import 'package:hightouch_events/flush_policies/count_flush_policy.dart';
import 'package:hightouch_events/flush_policies/flush_policy.dart';
import 'package:hightouch_events/flush_policies/startup_flush_policy.dart';
import 'package:hightouch_events/flush_policies/timer_flush_policy.dart';
import 'package:hightouch_events/plugins/event_logger.dart';
import 'package:hightouch_events/state.dart';
import 'package:hightouch_events/utils/store/store.dart';
import 'package:flutter/widgets.dart';

export 'package:hightouch_events/state.dart' show Configuration;

Analytics createClient(Configuration configuration) {
  if (configuration.debug) {
    Analytics.debug = true;
  }
  if (configuration.flushPolicies == null) {
    configuration = setFlushPolicies(configuration, defaultFlushPolicies);
  }

  final analytics = Analytics(configuration, storeFactory());

  if (configuration.debug) {
    analytics.addPlugin(EventLogger());
  }

  analytics.init();
  ScreenObserver().screenStream.listen((name) {
    analytics.screen(name);
  });

  return analytics;
}

mixin ClientMethods {
  Future track(String event, {Map<String, dynamic>? properties, Map<String, dynamic>? context});
  Future screen(String name, {Map<String, dynamic>? properties, Map<String, dynamic>? context});
  Future identify({String? userId, UserTraits? userTraits, Map<String, dynamic>? context});
  Future group(String groupId, {GroupTraits? groupTraits, Map<String, dynamic>? context});
  Future alias(String newUserId, {Map<String, dynamic>? context});
  Future flush();
  Future reset({bool? resetAnonymousId});
}

List<FlushPolicy> defaultFlushPolicies = [
  StartupFlushPolicy(),
  TimerFlushPolicy(20000),
  CountFlushPolicy(30),
];

class ScreenObserver extends NavigatorObserver {
  final StreamController<String> screenStreamController = StreamController.broadcast();

  Stream<String> get screenStream => screenStreamController.stream;

  static final ScreenObserver _singleton = ScreenObserver._internal();
  ScreenObserver._internal();
  factory ScreenObserver() {
    return _singleton;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = previousRoute?.settings.name;
    if (name != null) {
      screenStreamController.add(name);
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = route.settings.name;
    if (name != null) {
      screenStreamController.add(name);
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = route.settings.name;
    if (name != null) {
      screenStreamController.add(name);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final name = newRoute?.settings.name;
    if (name != null) {
      screenStreamController.add(name);
    }
  }
}
