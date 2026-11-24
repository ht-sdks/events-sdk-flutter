import 'dart:convert';

import 'package:hightouch_events/analytics.dart';
import 'package:hightouch_events/logger.dart';
import 'package:hightouch_events/event.dart';
import 'package:hightouch_events/plugin.dart';
import 'package:hightouch_events/state.dart';

typedef OnFlush = Future Function(List<RawEvent> events);

class QueueFlushingPlugin extends UtilityPlugin {
  QueueState<RawEvent>? _state;

  bool _isPendingUpload = false;
  final OnFlush _onFlush;
  final bool acknowledgeBatches;

  // Gets executed last to keep the queue after all timeline processing is done
  /// @param onFlush callback to execute when the queue is flushed (either by reaching the limit or manually) e.g. code to upload events to your destination
  QueueFlushingPlugin(this._onFlush, {this.acknowledgeBatches = false}) : super(PluginType.after);

  @override
  configure(Analytics analytics) {
    super.configure(analytics);

    var key = "queue_flushing_plugin";
    if (acknowledgeBatches) {
      final source = base64Url.encode(utf8.encode(analytics.state.configuration.state.writeKey));
      key = "${key}_$source";
      _reportUnownedQueue(analytics);
    }
    _state = QueueState(key, analytics.store, (json) => eventFromJson(json));
    _state!.init(analytics.error, true);
  }

  Future<void> _reportUnownedQueue(Analytics analytics) async {
    try {
      await analytics.store.ready;
      final old = await analytics.store.getPersisted("queue_flushing_plugin");
      if (old?['queue'] is List && (old!['queue'] as List).isNotEmpty) {
        log("The legacy upload queue has no source key. Its records are retained separately.", kind: LogFilterKind.warning);
      }
    } catch (error) {
      log("Unable to inspect the legacy upload queue: $error", kind: LogFilterKind.warning);
    }
  }

  @override
  Future<RawEvent> execute(RawEvent event) async {
    await _state!.ready;
    await _state!.add(event);
    return event;
  }

  /// Calls the onFlush callback with the events in the queue
  @override
  flush() async {
    final state = _state;
    if (state == null || _isPendingUpload) return;
    _isPendingUpload = true;
    try {
      await state.ready;
      final events = await state.events;
      await _onFlush(events);
      if (!acknowledgeBatches) await dequeue(events);
    } finally {
      _isPendingUpload = false;
    }
  }

  /// Removes one or multiple events from the queue
  /// @param events events to remove
  Future dequeue(List<RawEvent> eventsToRemove) async {
    await _state!.ready;
    await _state!.removeAll(eventsToRemove);
  }
}
