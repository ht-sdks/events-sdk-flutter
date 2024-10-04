import 'package:hightouch_events/analytics.dart';
import 'package:hightouch_events/analytics_platform_interface.dart';
import 'package:hightouch_events/logger.dart';
import 'package:hightouch_events/state.dart';
import 'package:hightouch_events/utils/http_client.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:mockito/mockito.dart';

import '../mocks/mocks.dart';
import '../mocks/mocks.mocks.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  group("HTTP Client", () {
    setUp(() {
      AnalyticsPlatform.instance = MockPlatform();
      LogFactory.logger = Mocks.logTarget();
    });
    test("It logs on bad response for get Settings", () async {
      final mockRequest = Mocks.request();
      when(mockRequest.send()).thenAnswer((_) => Future.value(StreamedResponse(const Stream.empty(), 300)));
      when(mockRequest.url).thenAnswer((_) => Uri.parse("http://hightouch-events.com"));
      HTTPClient client =
          HTTPClient(Analytics(Configuration("123", requestFactory: (_) => mockRequest), Mocks.store()));

      await client.settingsFor("123");

      verify(mockRequest.send());
      verify((LogFactory.logger as MockLogTarget).parseLog(captureAny));
    });
    test("It logs on bad response for send batch", () async {
      final mockRequest = Mocks.request();
      when(mockRequest.send()).thenAnswer((_) => Future.value(StreamedResponse(const Stream.empty(), 300)));
      when(mockRequest.url).thenAnswer((_) => Uri.parse("http://hightouch-events.com"));
      HTTPClient client =
          HTTPClient(Analytics(Configuration("123", requestFactory: (_) => mockRequest), Mocks.store()));

      await client.startBatchUpload("123", []);

      verify(mockRequest.send());
      verify((LogFactory.logger as MockLogTarget).parseLog(captureAny));
    });
  });
}
