import 'dart:async';

import 'package:hightouch_events/utils/lifecycle/lifecycle.dart';

class AppStateStreamMultiplexer {
  AppStateStreamMultiplexer._(this._factory);

  final StreamSubscription<AppStatus> Function(void Function(AppStatus) onData)
      _factory;

  final _controller = StreamController<AppStatus>.broadcast();
  StreamSubscription<AppStatus>? _sourceSubscription;

  factory AppStateStreamMultiplexer.fromFactory(
    StreamSubscription<AppStatus> Function(void Function(AppStatus) onData)
        factory,
  ) {
    return AppStateStreamMultiplexer._(factory);
  }

  StreamSubscription<AppStatus> listen(void Function(AppStatus) onData) {
    final listener = _controller.stream.listen(onData);
    _sourceSubscription ??= _factory((status) {
      if (!_controller.isClosed) {
        _controller.add(status);
      }
    });
    return listener;
  }

  Future<void> dispose() async {
    await _sourceSubscription?.cancel();
    _sourceSubscription = null;
    await _controller.close();
  }
}
