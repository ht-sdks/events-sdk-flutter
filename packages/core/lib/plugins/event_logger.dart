import 'dart:convert';

import 'package:hightouch_events/analytics.dart';
import 'package:hightouch_events/event.dart';
import 'package:hightouch_events/plugin.dart';
import 'package:hightouch_events/logger.dart';

class EventLogger extends DestinationPlugin {
  var logKind = LogFilterKind.debug;

  EventLogger() : super("event_logger");

  @override
  void configure(Analytics analytics) {
    pAnalytics = analytics;
  }

  @override
  Future<RawEvent?> execute(RawEvent event) async {
    log("${event.type.toString().toUpperCase()} event${event is TrackEvent ? " (${event.event})" : ''} saved: \n${jsonEncode(event.toJson())}",
        kind: logKind);
    return event;
  }
}
