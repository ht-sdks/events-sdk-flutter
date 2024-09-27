import 'dart:async';

import 'package:hightouch_events/analytics_platform_interface.dart';
import 'package:hightouch_events/logger.dart';
import 'package:hightouch_events/native_context.dart';
import 'package:hightouch_events/utils/http_client.dart';
import 'package:hightouch_events/utils/store/store.dart';
import 'package:http/http.dart';
import 'package:mockito/annotations.dart';

@GenerateNiceMocks([
  MockSpec<LogTarget>(),
  MockSpec<Request>(),
  MockSpec<StreamSubscription>(),
  MockSpec<HTTPClient>(),
  MockSpec<Store>()
])
import 'mocks.mocks.dart';

class MockPlatform extends AnalyticsPlatform {
  @override
  Future<NativeContext> getContext({bool collectDeviceId = false}) {
    return Future.value(NativeContext(
        app: NativeContextApp(),
        device: NativeContextDevice(),
        library: NativeContextLibrary(),
        network: NativeContextNetwork(),
        os: NativeContextOS(),
        screen: NativeContextScreen()));
  }
}

class Mocks {
  static MockLogTarget logTarget() => MockLogTarget();
  static MockRequest request() => MockRequest();
  static MockStreamSubscription<T> streamSubscription<T>() => MockStreamSubscription<T>();
  static MockHTTPClient httpClient() => MockHTTPClient();
  static MockStore store() => MockStore();
}
