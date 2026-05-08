import 'dart:convert';

import 'package:hightouch_events/analytics.dart';
import 'package:hightouch_events/errors.dart';
import 'package:hightouch_events/event.dart';
import 'package:hightouch_events/logger.dart';
import 'package:hightouch_events/state.dart';
import 'package:http/http.dart' as http;

class HTTPClient {
  static const defaultAPIHost = "https://us-east-1.hightouch-events.com";
  static const defaultCDNHost = "https://cdn-settings.hightouch-events.com";

  final WeakReference<Analytics> _analytics;

  HTTPClient(Analytics analytics) : _analytics = WeakReference(analytics);

  Uri _url(String host, String path) {
    String s = "$host$path";
    Uri result = Uri.parse(s);
    return result;
  }

  /// Starts an upload of events. Responds appropriately if successful or not. If not, lets the respondant
  /// know if the task should be retried or not based on the response.
  /// - Parameters:
  ///   - key: The write key the events are assocaited with.
  ///   - batch: The array of the events, considered a batch of events.
  ///   - completion: The closure executed when done. Passes if the task should be retried or not if failed.
  Future<bool> startBatchUpload(String writeKey, List<RawEvent> batch, {String? host}) async {
    final apihost = _analytics.target!.state.configuration.state.apiHost ?? host ?? defaultAPIHost;
    Uri uploadURL = _url(apihost, "/v1/batch");

    try {
      var urlRequest = _configuredRequest(uploadURL, "POST",
          body: jsonEncode({
            "batch": batch.map((e) => e.toJson()).toList(),
            "sentAt": DateTime.now().toUtc().toIso8601String(),
            "writeKey": _analytics.target!.state.configuration.state.writeKey,
          }));
      var f = urlRequest.send().then(http.Response.fromStream);

      var response = await f;

      if (response.statusCode < 300) {
        return true;
      } else if (response.statusCode < 400) {
        reportInternalError(NetworkUnexpectedHTTPCode(response.statusCode), analytics: _analytics.target);
        return false;
      } else if (response.statusCode == 429) {
        reportInternalError(NetworkServerLimited(response.statusCode), analytics: _analytics.target);
        return false;
      } else {
        reportInternalError(NetworkServerRejected(response.statusCode), analytics: _analytics.target);
        return false;
      }
    } catch (error) {
      log("Error uploading request ${error.toString()}", kind: LogFilterKind.error);
      return false;
    }
  }

  Future<HightouchAPISettings?> settingsFor(String writeKey) async {
    final settingsURL =
        _url(_analytics.target!.state.configuration.state.cdnHost, "/projects/$writeKey/settings");
    final urlRequest = _configuredRequest(settingsURL, "GET");

    try {
      final response = await urlRequest.send();

      if (response.statusCode > 300) {
        reportInternalError(NetworkUnexpectedHTTPCode(response.statusCode), analytics: _analytics.target);
        return null;
      }
      final data = await response.stream.toBytes();
      const decoder = JsonDecoder();
      final jsonMap = decoder.convert(utf8.decode(data)) as Map<String, dynamic>;
      return HightouchAPISettings.fromJson(jsonMap);
    } catch (error) {
      reportInternalError(NetworkUnknown(error.toString()), analytics: _analytics.target);
      return null;
    }
  }

  http.Request _configuredRequest(Uri url, String method, {String? body}) {
    var request = http.Request(method, url);
    request.headers.addAll({
      "Content-Type": "application/json; charset=utf-8",
      "User-Agent": "events-sdk-flutter/${Analytics.version()}",
      "Accept-Encoding": "gzip"
    });
    if (body != null) {
      request.body = body;
    }
    return _analytics.target?.state.configuration.state.requestFactory != null
        ? _analytics.target!.state.configuration.state.requestFactory!(request)
        : request;
  }
}
