import 'dart:async';
import 'package:hightouch_events/errors.dart';

import 'store.dart';

class StoreImpl with Store {
  @override
  Future<Map<String, dynamic>?> getPersisted(String key) {
    throw PlatformNotSupportedError();
  }

  @override
  Future get ready => throw PlatformNotSupportedError();

  @override
  Future setPersisted(String key, Map<String, dynamic> value) {
    throw PlatformNotSupportedError();
  }

  @override
  void dispose() {
    throw PlatformNotSupportedError();
  }
}
