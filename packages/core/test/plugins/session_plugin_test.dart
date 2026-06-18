import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hightouch_events/analytics.dart';
import 'package:hightouch_events/analytics_platform_interface.dart';
import 'package:hightouch_events/event.dart';
import 'package:hightouch_events/native_context.dart';
import 'package:hightouch_events/plugin.dart';
import 'package:hightouch_events/plugins/session/session_plugin.dart';
import 'package:hightouch_events/plugins/session/session_state_coordinator.dart';
import 'package:hightouch_events/state.dart';
import 'package:hightouch_events/utils/lifecycle/lifecycle.dart';

import '../helpers/memory_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionPlugin', () {
    late TestClock clock;
    TestClient? testClient;

    setUp(() {
      AnalyticsPlatform.instance = TestPlatform();
      SharedPreferences.setMockInitialValues({});
      clock = TestClock(1000);
    });

    tearDown(() async {
      await testClient?.dispose();
      testClient = null;
    });

    Future<TestClient> setupClient({
      MemoryStore? store,
      int foregroundSessionTimeout = 2000,
      int backgroundSessionTimeout = 2000,
    }) async {
      final client = await TestClient.create(
        clock: clock,
        store: store ?? MemoryStore(),
        foregroundSessionTimeout: foregroundSessionTimeout,
        backgroundSessionTimeout: backgroundSessionTimeout,
      );
      testClient = client;
      return client;
    }

    test('assigns unique sequential event indices when session reads overlap',
        () async {
      var sessionStateReads = 0;
      final releaseReads = Completer<void>();
      final sessionStateCoordinator = SessionStateCoordinator(
        afterRead: (state) async {
          sessionStateReads++;
          if (sessionStateReads > 1) {
            await releaseReads.future;
          }
        },
      );
      final client = await TestClient.create(
        clock: clock,
        store: MemoryStore(),
        foregroundSessionTimeout: 100000,
        backgroundSessionTimeout: 100000,
        sessionStateCoordinator: sessionStateCoordinator,
      );

      await client.analytics.track('First Event');

      final concurrentTracks = [
        client.analytics.track('Concurrent 1'),
        client.analytics.track('Concurrent 2'),
      ];
      await Future<void>.delayed(Duration.zero);
      releaseReads.complete();
      await Future.wait(concurrentTracks);

      final indices = client.output.events
          .skip(1)
          .map((event) =>
              (event.context!.toJson()['session'] as Map<String, dynamic>)[
                  'eventIndex'] as int)
          .toList();

      expect(indices, [1, 2]);
    });

    test(
        'allows Analytics and SessionPlugin to share a single-subscription appStateStream',
        () async {
      final controller = StreamController<AppStatus>();
      var factoryCallCount = 0;

      final analytics = Analytics(
        Configuration(
          'write-key',
          autoAddHightouchDestination: false,
          trackApplicationLifecycleEvents: true,
          appStateStream: (onData) {
            factoryCallCount++;
            return controller.stream.listen(onData);
          },
        ),
        MemoryStore(),
      );

      await analytics.state.ready;
      await analytics.init();

      expect(factoryCallCount, 1);

      await analytics.track('First Event');
      controller.add(AppStatus.background);
      await Future<void>.delayed(Duration.zero);

      final sessionState = await analytics.state.sessionState.state;
      expect(sessionState?.backgroundedAt, isNotNull);

      await analytics.cleanup();
    });

    test('rotates after background timeout using appStateStream when provided',
        () async {
      final controller = StreamController<AppStatus>.broadcast();
      final client = await TestClient.create(
        clock: clock,
        store: MemoryStore(),
        foregroundSessionTimeout: 100000,
        backgroundSessionTimeout: 2000,
        appStateStream: (onData) => controller.stream.listen(onData),
      );

      await client.analytics.track('First Event');
      clock.value = 1500;
      controller.add(AppStatus.background);
      await Future<void>.delayed(Duration.zero);

      clock.value = 4000;
      controller.add(AppStatus.foreground);
      await Future<void>.delayed(Duration.zero);

      await client.analytics.track('Foreground Event');

      final session = client.output.lastSession;
      expect(session['sessionId'], 4000);
      expect(session['sessionIndex'], 1);
      expect(session['previousSessionId'], 1000);
    });

    test('adds session context to every event', () async {
      final client = await setupClient();

      await client.analytics.track('First Event');
      clock.value = 1500;
      await client.analytics.track('Second Event');

      final firstContext = client.output.contextAt(0);
      final firstSession = firstContext['session'] as Map<String, dynamic>;
      expect(firstContext['sessionId'], 1000);
      expect(firstContext['sessionStart'], true);
      expect(firstSession['sessionId'], 1000);
      expect(firstSession['sessionIndex'], 0);
      expect(firstSession['sessionStart'], true);
      expect(firstSession['eventIndex'], 0);
      expect(firstSession['previousSessionId'], isNull);
      expect(firstSession['firstEventId'], client.output.events[0].messageId);
      expect(firstSession['firstEventTimestamp'],
          client.output.events[0].timestamp);

      final secondContext = client.output.contextAt(1);
      final secondSession = secondContext['session'] as Map<String, dynamic>;
      expect(secondContext['sessionId'], 1000);
      expect(secondContext.containsKey('sessionStart'), false);
      expect(secondSession['eventIndex'], 1);
      expect(secondSession.containsKey('sessionStart'), false);
    });

    test('rotates on foreground inactivity', () async {
      final client = await setupClient();

      await client.analytics.track('First Event');
      clock.value = 3001;
      await client.analytics.track('Rotated Event');

      final context = client.output.contextAt(1);
      final session = context['session'] as Map<String, dynamic>;
      expect(context['sessionId'], 3001);
      expect(context['sessionStart'], true);
      expect(session['sessionId'], 3001);
      expect(session['sessionIndex'], 1);
      expect(session['previousSessionId'], 1000);
      expect(session['eventIndex'], 0);
    });

    test('rotates after the app spends longer than the background timeout away',
        () async {
      final client = await setupClient();

      await client.analytics.track('First Event');
      clock.value = 1500;
      await client.sessionPlugin.handleAppStateChange(AppStatus.background);

      clock.value = 4000;
      await client.sessionPlugin.handleAppStateChange(AppStatus.foreground);
      await client.analytics.track('Foreground Event');

      final session = client.output.lastSession;
      expect(session['sessionId'], 4000);
      expect(session['sessionIndex'], 1);
      expect(session['previousSessionId'], 1000);
      expect(session['firstEventId'], client.output.events.last.messageId);
    });

    test(
        'preserves the background timestamp when events are processed while backgrounded',
        () async {
      final client = await setupClient();

      await client.analytics.track('First Event');
      clock.value = 1500;
      await client.sessionPlugin.handleAppStateChange(AppStatus.background);

      clock.value = 1501;
      await client.analytics.track('Application Backgrounded');

      clock.value = 4000;
      await client.sessionPlugin.handleAppStateChange(AppStatus.foreground);
      await client.analytics.track('Foreground Event');

      final session = client.output.lastSession;
      expect(session['sessionId'], 4000);
      expect(session['sessionIndex'], 1);
      expect(session['sessionStart'], true);
      expect(session['eventIndex'], 0);
      expect(session['previousSessionId'], 1000);
    });

    test('uses rotated session when track follows unawaited reset', () async {
      final allowResetRotation = Completer<void>();
      final client = await TestClient.create(
        clock: clock,
        store: MemoryStore(),
        foregroundSessionTimeout: 100000,
        backgroundSessionTimeout: 100000,
        sessionStateCoordinator: SessionStateCoordinator(
          beforeRotateOnReset: () => allowResetRotation.future,
        ),
      );
      testClient = client;

      await client.analytics.track('First Event');
      clock.value = 5000;

      client.analytics.reset();
      final trackFuture = client.analytics.track('After Reset');

      await Future<void>.delayed(Duration.zero);
      allowResetRotation.complete();
      await trackFuture;

      final session = client.output.lastSession;
      expect(session['sessionId'], 5000);
      expect(session['sessionIndex'], 1);
      expect(session['sessionStart'], true);
      expect(session['previousSessionId'], 1000);
    });

    test('uses rotated session when reset follows an in-flight track', () async {
      final allowResetRotation = Completer<void>();
      final releaseTrackRead = Completer<void>();
      final client = await TestClient.create(
        clock: clock,
        store: MemoryStore(),
        foregroundSessionTimeout: 100000,
        backgroundSessionTimeout: 100000,
        sessionStateCoordinator: SessionStateCoordinator(
          beforeRotateOnReset: () => allowResetRotation.future,
          afterRead: (state) async {
            if (state?.sessionId == 1000) {
              await releaseTrackRead.future;
            }
          },
        ),
      );
      testClient = client;

      await client.analytics.track('First Event');
      clock.value = 5000;

      final trackFuture = client.analytics.track('After Reset');
      await Future<void>.delayed(Duration.zero);
      client.analytics.reset();
      releaseTrackRead.complete();
      allowResetRotation.complete();
      await trackFuture;

      final session = client.output.lastSession;
      expect(session['sessionId'], 5000);
      expect(session['sessionIndex'], 1);
      expect(session['sessionStart'], true);
      expect(session['previousSessionId'], 1000);
    });

    test(
        'rotates after background timeout when track precedes foreground lifecycle',
        () async {
      final client = await setupClient();

      await client.analytics.track('First Event');
      clock.value = 1500;
      await client.sessionPlugin.handleAppStateChange(AppStatus.background);

      clock.value = 4000;
      await client.analytics.track('Foreground Event');

      final session = client.output.lastSession;
      expect(session['sessionId'], 4000);
      expect(session['sessionIndex'], 1);
      expect(session['previousSessionId'], 1000);
    });

    test('rotates when the client resets', () async {
      final client = await setupClient();

      await client.analytics.track('First Event');
      clock.value = 5000;
      await client.analytics.reset();
      await client.analytics.track('After Reset');

      final session = client.output.lastSession;
      expect(session['sessionId'], 5000);
      expect(session['sessionIndex'], 1);
      expect(session['sessionStart'], true);
      expect(session['previousSessionId'], 1000);
      expect(session['firstEventId'], client.output.events.last.messageId);
    });

    test('does not register or enrich when both timeouts are zero', () async {
      final client = await setupClient(
        foregroundSessionTimeout: 0,
        backgroundSessionTimeout: 0,
      );

      await client.analytics.track('No Session Event');

      expect(
        client.analytics
            .getPlugins(PluginType.enrichment)
            .whereType<SessionPlugin>(),
        isEmpty,
      );
      final context = client.output.contextAt(0);
      expect(context['session'], isNull);
      expect(context['sessionId'], isNull);
    });

    test('persists session state across analytics instances', () async {
      final store = MemoryStore();
      var client = await setupClient(store: store);

      await client.analytics.track('First Event');
      clock.value = 1500;
      await client.sessionPlugin.handleAppStateChange(AppStatus.background);
      await Future<void>.delayed(Duration.zero);
      await client.dispose();
      testClient = null;

      clock.value = 4000;
      client = await setupClient(store: store);
      await client.analytics.track('Cold Start Event');

      final session = client.output.lastSession;
      expect(session['sessionId'], 4000);
      expect(session['sessionIndex'], 1);
      expect(session['previousSessionId'], 1000);
      expect(session['firstEventId'], client.output.events.last.messageId);
    });
  });
}

class TestClient {
  final Analytics analytics;
  final SessionPlugin sessionPlugin;
  final CapturePlugin output;

  TestClient({
    required this.analytics,
    required this.sessionPlugin,
    required this.output,
  });

  static Future<TestClient> create({
    required TestClock clock,
    required MemoryStore store,
    required int foregroundSessionTimeout,
    required int backgroundSessionTimeout,
    StreamSubscription<AppStatus> Function(void Function(AppStatus) onData)?
        appStateStream,
    SessionStateCoordinator? sessionStateCoordinator,
  }) async {
    final analytics = Analytics(
      Configuration(
        'write-key',
        autoAddHightouchDestination: false,
        foregroundSessionTimeout: foregroundSessionTimeout,
        backgroundSessionTimeout: backgroundSessionTimeout,
        trackApplicationLifecycleEvents: false,
        appStateStream: appStateStream,
      ),
      store,
    );

    await analytics.state.ready;
    await Future<void>.delayed(Duration.zero);

    for (final plugin in analytics
        .getPlugins(PluginType.enrichment)
        .whereType<SessionPlugin>()
        .toList()) {
      plugin.shutdown();
      analytics.removePlugin(plugin);
    }

    final sessionPlugin = SessionPlugin(
      now: clock.now,
      sessionStateCoordinator: sessionStateCoordinator,
    );
    if (foregroundSessionTimeout != 0 || backgroundSessionTimeout != 0) {
      analytics.addPlugin(sessionPlugin);
    }

    final output = CapturePlugin();
    analytics.addPlugin(output);

    return TestClient(
      analytics: analytics,
      sessionPlugin: sessionPlugin,
      output: output,
    );
  }

  Future<void> dispose() async {
    sessionPlugin.shutdown();
    await analytics.cleanup();
  }
}

class TestClock {
  int value;

  TestClock(this.value);

  int now() => value;
}

class CapturePlugin extends PlatformPlugin {
  final List<RawEvent> events = [];

  CapturePlugin() : super(PluginType.after);

  Map<String, dynamic> get lastSession =>
      contextAt(events.length - 1)['session'] as Map<String, dynamic>;

  Map<String, dynamic> contextAt(int index) => events[index].context!.toJson();

  @override
  Future<RawEvent?> execute(RawEvent event) async {
    events.add(event);
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
