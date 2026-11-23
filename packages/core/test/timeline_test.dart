import 'dart:async';
import 'package:hightouch_events/native_context.dart';
import 'package:hightouch_events/analytics.dart';
import 'package:hightouch_events/analytics_platform_interface.dart';
import 'package:hightouch_events/event.dart';
import 'package:hightouch_events/logger.dart';
import 'package:hightouch_events/plugin.dart';
import 'package:hightouch_events/state.dart';
import 'package:hightouch_events/timeline.dart';
import 'package:hightouch_events/utils/http_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/memory_store.dart';
import 'mocks/mocks.dart';

/// A destination plugin whose async work only completes after a timer tick.
/// This simulates the real HightouchDestination, whose internal pipeline
/// (enrichment -> QueueFlushingPlugin persistence) spans several event-loop
/// turns before the event is actually queued.
class _SlowQueueingDestination extends Plugin {
  bool eventQueued = false;

  _SlowQueueingDestination() : super(PluginType.destination);

  @override
  Future<RawEvent?> execute(RawEvent event) async {
    // A timer-based hop is guaranteed to run after all pending microtasks,
    // so if the timeline does not await this future, process() will resolve
    // before eventQueued is set.
    await Future<void>.delayed(Duration.zero);
    eventQueued = true;
    return event;
  }
}

/// Captures the batches uploaded via startBatchUpload instead of hitting the
/// network.
class _CapturingHTTPClient extends HTTPClient {
  final List<List<RawEvent>> uploadedBatches = [];

  bool succeeds = true;
  _CapturingHTTPClient(super.analytics);

  @override
  Future<bool> startBatchUpload(String writeKey, List<RawEvent> batch,
      {String? host}) async {
    uploadedBatches.add(List.of(batch));
    return succeeds;
  }
}

class _WaitingPlatform extends MockPlatform {
  @override
  Future<NativeContext> getContext({bool collectDeviceId = false}) => Completer<NativeContext>().future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("Timeline destination handling", () {
    test("process() does not resolve until destination plugins finish queueing",
        () async {
      final timeline = Timeline();
      final destination = _SlowQueueingDestination();
      timeline.add(destination);

      await timeline.process(TrackEvent("Test Event"));

      expect(destination.eventQueued, isTrue,
          reason: "timeline.process() resolved before the destination plugin "
              "finished executing, so a flush() right after track() can miss "
              "the event");
    });
  });

  group("flush after track (regression for missed flush events)", () {
    setUp(() {
      AnalyticsPlatform.instance = MockPlatform();
      // Prevents spamming the test console.
      LogFactory.logger = Mocks.logTarget();
      SharedPreferences.setMockInitialValues({});
    });

    test("a restarted client recovers pre-ready identity and excludes callbacks", () async {
      final records = <String, Map<String, dynamic>>{};
      final config = Configuration("restart", trackApplicationLifecycleEvents: false,
          appStateStream: (_) => Mocks.streamSubscription());
      AnalyticsPlatform.instance = _WaitingPlatform();
      final first = Analytics(config, MemoryStore(records));
      await first.identify(userId: "original");
      await first.track("early");
      await first.track("session only", enrichment: (e) => e);
      final saved = records.entries.singleWhere((e) => e.key.startsWith("startup_")).value["events"] as List;
      expect(saved, hasLength(2));
      final original = saved.last;
      await first.cleanup();

      AnalyticsPlatform.instance = MockPlatform();
      late _CapturingHTTPClient http;
      final next = Analytics(config, MemoryStore(records), httpClient: (a) => http = _CapturingHTTPClient(a));
      await next.state.ready;
      await next.track("ready");
      await next.flush();

      final tracks = http.uploadedBatches.expand((b) => b).whereType<TrackEvent>();
      final early = tracks.singleWhere((event) => event.event == "early");
      expect(early.messageId, original["messageId"]);
      expect(early.timestamp, original["timestamp"]);
      expect(early.anonymousId, original["anonymousId"]);
      expect(early.userId, "original");
      expect(tracks.any((event) => event.event == "session only"), isFalse);
      await next.cleanup();
    });

    test("an unowned legacy queue is retained separately", () async {
      final legacy = {"queue": [TrackEvent("legacy").toJson()]};
      final store = MemoryStore({"queue_flushing_plugin": legacy});
      late _CapturingHTTPClient http;
      final analytics = Analytics(
          Configuration("new-source", trackApplicationLifecycleEvents: false,
              appStateStream: (_) => Mocks.streamSubscription()),
          store, httpClient: (a) => http = _CapturingHTTPClient(a));
      await analytics.state.ready;
      await analytics.track("new");
      await analytics.flush();
      expect(http.uploadedBatches.expand((batch) => batch).whereType<TrackEvent>()
          .map((event) => event.event), ["new"]);
      expect(await store.getPersisted("queue_flushing_plugin"), legacy);
    });

    test("a rejected batch is replayed with the same IDs on the next flush", () async {
      late _CapturingHTTPClient http;
      final analytics = Analytics(
          Configuration("source", trackApplicationLifecycleEvents: false,
              appStateStream: (_) => Mocks.streamSubscription()),
          MemoryStore(), httpClient: (a) => http = _CapturingHTTPClient(a));
      await analytics.state.ready;
      http.succeeds = false;
      await analytics.track("retry");
      await analytics.flush();
      http.succeeds = true;
      await analytics.flush();
      await analytics.flush();
      expect(http.uploadedBatches, hasLength(2));
      expect(http.uploadedBatches.first.map((e) => e.messageId),
          http.uploadedBatches.last.map((e) => e.messageId));
    });

    test("flush() immediately after an awaited track() uploads the event",
        () async {
      _CapturingHTTPClient? httpClient;
      final analytics = Analytics(
          Configuration("123",
              trackApplicationLifecycleEvents: false,
              appStateStream: (_) => Mocks.streamSubscription()),
          MemoryStore(),
          httpClient: (analytics) =>
              httpClient = _CapturingHTTPClient(analytics));
      await analytics.state.ready;

      await analytics.track("Test Event");
      await analytics.flush();

      expect(httpClient!.uploadedBatches, hasLength(1),
          reason: "the flushed batch should have been uploaded exactly once");
      expect(
          httpClient!.uploadedBatches.single
              .whereType<TrackEvent>()
              .map((trackEvent) => trackEvent.event)
              .toList(),
          contains("Test Event"),
          reason: "the event tracked right before flush() must be included "
              "in the uploaded batch");
    });
  });
}
