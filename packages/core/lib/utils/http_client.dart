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

  DateTime? _nextProbe;
  int _probeDelay = 1;
  bool get waitingForProbe => _nextProbe?.isAfter(DateTime.now()) == true;
  void _deferProbe() {
    _nextProbe = DateTime.now().add(Duration(seconds: _probeDelay));
    _probeDelay = (_probeDelay * 2).clamp(1, 60).toInt();
  }

  final _permanentRejections = Expando<bool>();

  bool permanentlyRejected(List<RawEvent> batch) => _permanentRejections[batch] == true;

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
    if (waitingForProbe) return false;
    _permanentRejections[batch] = null;
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

      final status = response.statusCode;
      if (status == 401 || status == 403 || status == 404) {
        _deferProbe();
        log("HTTP $status. Check the write key and endpoint. Events will be retried.", kind: LogFilterKind.error);
      } else if (_nextProbe != null && (status == 408 || status == 429 || (status >= 500 && status < 600))) {
        _deferProbe();
      } else if (status >= 400 && status < 500 && status != 408 && status != 429) {
        _permanentRejections[batch] = true;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _nextProbe = null;
        _probeDelay = 1;
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
      if (_nextProbe != null) _deferProbe();
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
