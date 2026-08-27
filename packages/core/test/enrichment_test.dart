import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hightouch_events/analytics.dart';
import 'package:hightouch_events/analytics_platform_interface.dart';
import 'package:hightouch_events/event.dart';
import 'package:hightouch_events/native_context.dart';
import 'package:hightouch_events/plugin.dart';
import 'package:hightouch_events/state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/memory_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Analytics analytics;
  late CapturePlugin output;

  setUp(() async {
    AnalyticsPlatform.instance = TestPlatform();
    SharedPreferences.setMockInitialValues({});

    analytics = Analytics(
      Configuration(
        'write-key',
        autoAddHightouchDestination: false,
        foregroundSessionTimeout: 0,
        backgroundSessionTimeout: 0,
        trackApplicationLifecycleEvents: false,
      ),
      MemoryStore(),
    );
    output = CapturePlugin();
    analytics.addPlugin(output);

    await analytics.state.ready;
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(() async {
    await analytics.cleanup();
  });

  test('track enrichment closure stamps protocols while keeping platform context',
      () async {
    await analytics.track('TrackFooV1', enrichment: _stampSchemaVersion('v1'));

    expect(output.events, hasLength(1));
    final context = output.events.single.context!.toJson();
    expect((context['protocols'] as Map)['schemaVersion'], 'v1');
    expect(context['library'], isNotNull);
    expect(context['os'], isNotNull);
  });

  test('overlapping alias calls with different closures keep their own stamps',
      () async {
    final releaseEnrichment = Completer<void>();
    final bothReachedEnrichment = Completer<void>();
    var enrichmentStarts = 0;
    analytics.addPlugin(_HoldEnrichment(
      onExecute: () {
        enrichmentStarts++;
        if (enrichmentStarts == 2 && !bothReachedEnrichment.isCompleted) {
          bothReachedEnrichment.complete();
        }
        return releaseEnrichment.future;
      },
    ));

    final first =
        analytics.alias('user-v1', enrichment: _stampSchemaVersion('v1'));
    final second =
        analytics.alias('user-v2', enrichment: _stampSchemaVersion('v2'));

    await bothReachedEnrichment.future;
    releaseEnrichment.complete();
    await Future.wait([first, second]);

    final byUserId = {for (final event in output.events) event.userId: event};
    expect(_schemaVersion(byUserId['user-v1']!), 'v1');
    expect(_schemaVersion(byUserId['user-v2']!), 'v2');
  });

  test('a later event without enrichment has no protocols key', () async {
    await analytics.track('TrackFooV1', enrichment: _stampSchemaVersion('v1'));
    await analytics.track('TrackPlain');

    final plain = output.events
        .whereType<TrackEvent>()
        .firstWhere((event) => event.event == 'TrackPlain');
    final context = plain.context!.toJson();
    expect(context['protocols'], isNull);
    expect(context['library'], isNotNull);
  });

  test('enrichment closure survives a plugin that returns a fresh event',
      () async {
    analytics.addPlugin(_ReplaceEventPlugin());

    await analytics.track('TrackReplaced',
        enrichment: _stampSchemaVersion('v9'));

    expect(output.events, hasLength(1));
    expect(_schemaVersion(output.events.single), 'v9');
    expect(output.events.single.context!.toJson()['library'], isNotNull);
  });

  test('processed events serialize without any enrichment key', () async {
    await analytics.track('TrackNoEnrichment');

    expect(output.events, hasLength(1));
    final encoded = jsonEncode(output.events.single.toJson());
    expect(encoded, isNot(contains('enrichment')));
  });

  test('a stashed enrichment closure leaves serialized payloads byte-identical',
      () {
    final withoutClosure = TrackEvent('Same Event', properties: {'a': 1})
      ..messageId = 'fixed-message-id'
      ..timestamp = '2026-01-01T00:00:00.000Z';
    final withClosure = TrackEvent('Same Event', properties: {'a': 1})
      ..messageId = 'fixed-message-id'
      ..timestamp = '2026-01-01T00:00:00.000Z'
      ..enrichment = (event) => event;

    expect(jsonEncode(withClosure.toJson()),
        jsonEncode(withoutClosure.toJson()));
    expect(withClosure.toJson().containsKey('enrichment'), isFalse);
  });
}

/// Returns a closure that stamps `context.protocols.schemaVersion` onto the
/// event. The shared platform [Context] instance is copied first so that
/// overlapping events don't observe each other's per-call enrichment — merge
/// semantics belong inside the closure.
EnrichmentClosure _stampSchemaVersion(String version) {
  return (event) {
    final context = event.context!;
    event.context = Context(
      context.app,
      context.device,
      context.library,
      context.locale,
      context.network,
      context.os,
      context.screen,
      context.timezone,
      context.traits,
      instanceId: context.instanceId,
      custom: {
        ...context.custom,
        'protocols': {'schemaVersion': version},
      },
    );
    return event;
  };
}

String? _schemaVersion(RawEvent event) {
  final protocols = event.context?.toJson()['protocols'];
  if (protocols is Map) {
    return protocols['schemaVersion'] as String?;
  }
  return null;
}

class CapturePlugin extends PlatformPlugin {
  CapturePlugin() : super(PluginType.after);

  final List<RawEvent> events = [];

  @override
  Future<RawEvent?> execute(RawEvent event) async {
    events.add(event);
    return event;
  }
}

/// Returns a brand-new event instance without carrying over the (non-JSON)
/// `enrichment` field, simulating plugins that rebuild events, e.g. via a
/// toJson/fromJson round trip.
class _ReplaceEventPlugin extends PlatformPlugin {
  _ReplaceEventPlugin() : super(PluginType.enrichment);

  @override
  Future<RawEvent?> execute(RawEvent event) async {
    final track = event as TrackEvent;
    return TrackEvent(track.event, properties: track.properties)
      ..anonymousId = track.anonymousId
      ..messageId = track.messageId
      ..userId = track.userId
      ..timestamp = track.timestamp
      ..context = track.context
      ..integrations = track.integrations;
  }
}

class _HoldEnrichment extends PlatformPlugin {
  _HoldEnrichment({required this.onExecute}) : super(PluginType.enrichment);

  final Future<void> Function() onExecute;

  @override
  Future<RawEvent?> execute(RawEvent event) async {
    await onExecute();
    return event;
  }
}

class TestPlatform extends AnalyticsPlatform {
  @override
  Future<NativeContext> getContext({bool collectDeviceId = false}) async {
    return NativeContext(
      app: NativeContextApp(),
      device: NativeContextDevice(),
      library: NativeContextLibrary(),
      network: NativeContextNetwork(),
      os: NativeContextOS(),
      screen: NativeContextScreen(),
    );
  }
}
