import 'package:hightouch_events/analytics.dart';
import 'package:hightouch_events/event.dart';
import 'package:hightouch_events/plugin.dart';
import 'package:hightouch_events/state.dart';

class InjectUserInfo extends PlatformPlugin {
  InjectUserInfo() : super(PluginType.before);

  static final captured = Expando<bool>();

  @override
  Future<RawEvent> execute(RawEvent event) async {
    if (captured[event] == true) return event;
    return apply(analytics!, event);
  }

  static Future<RawEvent> apply(Analytics client, RawEvent event) async {
    final userInfo = await client.state.userInfo.state;
    event.anonymousId = userInfo.anonymousId;
    if (event.type == EventType.identify) {
      final identityEvent = event as IdentifyEvent;
      final mergedTraits = identityEvent.traits != null
          ? (userInfo.userTraits != null
              ? mergeUserTraits(identityEvent.traits as UserTraits, userInfo.userTraits as UserTraits)
              : identityEvent.traits)
          : userInfo.userTraits;
      client.state.userInfo.setState(UserInfo(event.anonymousId ?? userInfo.anonymousId,
          userId: event.userId ?? userInfo.userId,
          userTraits: mergedTraits,
          groupTraits: userInfo.groupTraits));

      identityEvent.traits = mergedTraits;
    } else if (event.type == EventType.alias) {
      final previousAnonId = userInfo.anonymousId;
      final previousUserId = userInfo.userId;
      client.state.userInfo.setState(UserInfo(event.anonymousId ?? userInfo.anonymousId,
          userId: event.userId, userTraits: userInfo.userTraits, groupTraits: userInfo.groupTraits));
      (event as AliasEvent).previousId = previousUserId ?? previousAnonId;
    } else if (event.type == EventType.group) {
      final groupEvent = event as GroupEvent;
      final mergedTraits = groupEvent.traits != null
          ? (userInfo.groupTraits != null
              ? mergeGroupTraits(groupEvent.traits as GroupTraits, userInfo.groupTraits as GroupTraits)
              : groupEvent.traits)
          : userInfo.groupTraits;
      client.state.userInfo.setState(UserInfo(event.anonymousId ?? userInfo.anonymousId,
          userId: event.userId ?? userInfo.userId,
          userTraits: userInfo.userTraits,
          groupTraits: mergedTraits));

      groupEvent.traits = mergedTraits;
    }

    event.userId ??= userInfo.userId;
    event.anonymousId ??= userInfo.anonymousId;

    return event;
  }
}
