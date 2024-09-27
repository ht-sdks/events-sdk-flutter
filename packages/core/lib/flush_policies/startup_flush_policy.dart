import 'package:hightouch_events/flush_policies/flush_policy.dart';

class StartupFlushPolicy extends FlushPolicy {
  @override
  start() {
    shouldFlush = true;
  }
}
