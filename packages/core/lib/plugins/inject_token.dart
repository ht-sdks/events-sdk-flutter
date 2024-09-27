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
    event.context = context;
    return event;
  }
}
