import 'dart:async';

import 'package:hightouch_events/event.dart';
import 'package:hightouch_events/flush_policies/flush_policy.dart';

class TimerFlushPolicy extends FlushPolicy {
  Timer? _timer;
  final int _interval;

  _startTimer() {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: _interval), () {
      shouldFlush = true;
      _timer = null;
      _startTimer();
    });
  }

  /// @param interval interval to flush in milliseconds
  TimerFlushPolicy(this._interval);

  @override
  start() {
    _startTimer();
  }

  @override
  onEvent(RawEvent event) {
    // Reset interval
    _startTimer();
  }

  @override
  reset() {
    super.reset();
    _startTimer();
  }
}
