import 'package:hightouch_events/analytics.dart';
import 'package:hightouch_events/event.dart';
import 'package:hightouch_events/plugin.dart';
import 'package:uuid/uuid.dart';

class InjectContext extends PlatformPlugin {
  InjectContext() : super(PluginType.before);

  final instanceId = const Uuid().v4();

  @override
  Future<RawEvent> execute(RawEvent event) async {
    // We need to get the Context in a concurrency safe mode to permit changes to make it in before we retrieve it
    final context = await analytics!.state.context.state;
    context!.instanceId = instanceId;
    context.library = ContextLibrary("events-sdk-flutter", Analytics.version());
    event.context = context;
    return event;
  }
}
