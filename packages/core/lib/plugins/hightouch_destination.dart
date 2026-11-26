import 'package:hightouch_events/analytics.dart';
import 'package:hightouch_events/event.dart';
import 'package:hightouch_events/plugin.dart';
import 'package:hightouch_events/plugins/destination_metadata_enrichment.dart';
import 'package:hightouch_events/plugins/queue_flushing_plugin.dart';
import 'package:hightouch_events/logger.dart';
import 'package:hightouch_events/utils/chunk.dart';

const maxEventsPerBatch = 100;
const maxPayloadSizeInKb = 500;
const hightouchDestinationKey = 'Hightouch.io';

class HightouchDestination extends DestinationPlugin with Flushable {
  late final QueueFlushingPlugin _queuePlugin;
  String? _apiHost;
  final _lastFailure = Expando<Stopwatch>();
  static const _retryDelay = Duration(seconds: 1);

  void _defer(List<RawEvent> batch) {
    final elapsed = Stopwatch()..start();
    for (final event in batch) {
      _lastFailure[event] = elapsed;
    }
  }

  HightouchDestination() : super(hightouchDestinationKey) {
    _queuePlugin = QueueFlushingPlugin(_sendEvents, acknowledgeBatches: true);
  }

  Future _sendEvents(List<RawEvent> events) async {
    if (events.isEmpty) {
      return;
    }

    final eligible = events.where((event) {
      final wait = _lastFailure[event];
      return wait == null || wait.elapsed >= _retryDelay;
    });
    final List<List<RawEvent>> chunkedEvents = chunk(
        eligible.toList(), analytics?.state.configuration.state.maxBatchSize ?? maxEventsPerBatch,
        maxKB: maxPayloadSizeInKb);

    var sentCount = 0;
    var numFailedEvents = 0;

    for (final batch in chunkedEvents) {
      var uploading = true;
      try {
        final succeeded = await analytics?.httpClient
            .startBatchUpload(analytics!.state.configuration.state.writeKey, batch, host: _apiHost);
        uploading = false;
        if (succeeded == true) {
          sentCount += batch.length;
        } else {
          numFailedEvents += batch.length;
          if (analytics?.httpClient.permanentlyRejected(batch) != true) {
            _defer(batch);
            continue;
          }
        }
        await _queuePlugin.dequeue(batch);
      } catch (e) {
        if (uploading) _defer(batch);
        numFailedEvents += batch.length;
      }
    }

    if (sentCount > 0) {
      log("Sent $sentCount events", kind: LogFilterKind.debug);
    }

    if (numFailedEvents > 0) {
      log("Failed to send $numFailedEvents events", kind: LogFilterKind.error);
    }

    return;
  }

  @override
  configure(Analytics analytics) {
    super.configure(analytics);

    // Enrich events with the Destination metadata
    add(DestinationMetadataEnrichment(hightouchDestinationKey));
    add(_queuePlugin);
  }

  @override
  void update(Map<String, dynamic> settings, ContextUpdateType type) {
    super.update(settings, type);
    _apiHost = settings[hightouchDestinationKey]?['apiHost'];
  }

  @override
  flush() {
    return _queuePlugin.flush();
  }
}
