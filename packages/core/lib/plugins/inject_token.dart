import 'package:hightouch_events/event.dart';
import 'package:hightouch_events/plugin.dart';

class InjectToken extends PlatformPlugin {
  InjectToken(this.token) : super(PluginType.before);

  final String token;

  @override
  Future<RawEvent> execute(RawEvent event) async {
    // We need to get the Context in a concurrency safe mode to permit changes to make it in before we retrieve it
    final context = await analytics!.state.context.state;
    context!.device.token = token;
    final eventContext = event.context;
    if (eventContext != null) {
      eventContext.device.token = token;
    } else {
      event.context = context;
    }
    return event;
  }
}
