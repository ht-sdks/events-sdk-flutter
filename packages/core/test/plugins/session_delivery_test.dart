import 'package:flutter_test/flutter_test.dart';
import 'package:hightouch_events/analytics.dart';
import 'package:hightouch_events/analytics_platform_interface.dart';
import 'package:hightouch_events/event.dart';
import 'package:hightouch_events/native_context.dart';
import 'package:hightouch_events/plugin.dart';
import 'package:hightouch_events/plugins/session/session_plugin.dart';
import 'package:hightouch_events/state.dart';

import '../helpers/memory_store.dart';

void main() {
  group('Session delivery', () {
    late TestClock clock;
    TestClient? testClient;

    setUp(() {
      AnalyticsPlatform.instance = TestPlatform();
      clock = TestClock(1000);
    });

    tearDown(() async {
      await testClient?.dispose();
      testClient = null;
    });

    test('uploads tracked events with session context', () async {
      final client = await TestClient.create(
        clock: clock,
        store: MemoryStore(),
        captureEvents: true,
      );
      testClient = client;

      await client.analytics.track('Purchase Completed');
      await client.analytics.flush();

      expect(client.capture!.events, hasLength(1));
      final eventJson = client.capture!.events.single.toJson();
      final custom = eventJson['context'] as Map<String, dynamic>;
      final session = custom['session'] as Map<String, dynamic>;

      expect(custom['sessionId'], 1000);
      expect(custom['sessionStart'], true);
      expect(session['sessionId'], 1000);
      expect(session['sessionIndex'], 0);
      expect(session['sessionStart'], true);
      expect(session['eventIndex'], 0);
      expect(session['previousSessionId'], isNull);
      expect(session['firstEventId'], client.capture!.events.single.messageId);
    });
  });
}

class TestClient {
  final Analytics analytics;
  final SessionPlugin sessionPlugin;
  final CapturePlugin? capture;

  TestClient({
    required this.analytics,
    required this.sessionPlugin,
    this.capture,
  });

  static Future<TestClient> create({
    required TestClock clock,
    required MemoryStore store,
    bool captureEvents = false,
  }) async {
    final analytics = Analytics(
      Configuration(
        'write-key',
        autoAddHightouchDestination: false,
        foregroundSessionTimeout: 1800000,
        backgroundSessionTimeout: 1800000,
        trackApplicationLifecycleEvents: false,
      ),
      store,
    );

    await analytics.state.ready;

    for (final plugin in analytics
        .getPlugins(PluginType.enrichment)
        .whereType<SessionPlugin>()
        .toList()) {
      plugin.shutdown();
      analytics.removePlugin(plugin);
    }

    final sessionPlugin = SessionPlugin(now: clock.now);
    analytics.addPlugin(sessionPlugin);

    CapturePlugin? capture;
    if (captureEvents) {
      capture = CapturePlugin();
      analytics.addPlugin(capture);
    }

    return TestClient(
      analytics: analytics,
      sessionPlugin: sessionPlugin,
      capture: capture,
    );
  }

  Future<void> dispose() async {
    sessionPlugin.shutdown();
    await analytics.cleanup();
  }
}

class CapturePlugin extends PlatformPlugin {
  final List<RawEvent> events = [];

  CapturePlugin() : super(PluginType.after);

  @override
  Future<RawEvent?> execute(RawEvent event) async {
    events.add(event);
    return event;
  }
}

class TestClock {
  int value;

  TestClock(this.value);

  int now() => value;
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
