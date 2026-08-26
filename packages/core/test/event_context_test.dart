import 'dart:async';

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

  test('track merges per-call context protocols.schemaVersion onto the processed event',
      () async {
    await analytics.track('TrackFooV1', context: {
      'protocols': {'schemaVersion': 'v1'},
    });

    expect(output.events, hasLength(1));
    final context = output.events.single.context!.toJson();
    expect((context['protocols'] as Map)['schemaVersion'], 'v1');
    expect(context['library'], isNotNull);
  });

  test('overlapping alias calls keep their own context', () async {
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

    final first = analytics.alias('user-v1', context: {
      'protocols': {'schemaVersion': 'v1'},
    });
    final second = analytics.alias('user-v2', context: {
      'protocols': {'schemaVersion': 'v2'},
    });

    await bothReachedEnrichment.future;
    releaseEnrichment.complete();
    await Future.wait([first, second]);

    final byUserId = {for (final event in output.events) event.userId: event};
    expect(_schemaVersion(byUserId['user-v1']!), 'v1');
    expect(_schemaVersion(byUserId['user-v2']!), 'v2');
  });

  test('omitted context leaves processed event context unchanged', () async {
    await analytics.track('TrackFoo');

    expect(output.events, hasLength(1));
    final context = output.events.single.context!.toJson();
    expect(context['protocols'], isNull);
    expect(context['library'], isNotNull);
  });
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
