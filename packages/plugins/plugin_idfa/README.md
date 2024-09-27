# hightouch_events_plugin_idfa

`Plugin` which retrieves IDFA data (iOS only). IDFA data will then be included in `event` payloads under `event.context.device`

**This plugin only works on iOS. Android calls will result in no-op.**

## Installation

Manually add this package to your `pubspec.yaml` file.

```yaml
dependencies:
  hightouch_events_plugin_idfa:
    git:
      url: https://github.com/ht-sdks/events-sdk-flutter
      ref: main
      path: packages/plugins/plugin_idfa
```

You also need to ensure you have a description for `NSUserTrackingUsageDescription` in your `Info.plist`, or your app will crash.

## Usage

Follow the [instructions for adding plugins](https://github.com/ht-sdks/events-sdk-flutter_#adding-plugins) on the main Analytics client:

In your code where you initialize the analytics client call the `.add(plugin)` method with an `PluginIdfa` instance.

```dart
import 'package:hightouch_events/client.dart';
import 'package:hightouch_events_plugin_idfa/plugin_idfa.dart'
    show PluginIdfa;

const writeKey = 'WRITE_KEY';

class _MyAppState extends State<MyApp> {
  final analytics = createClient(Configuration(writeKey));

  @override
  void initState() {
    // ...

    analytics
        .addPlugin(PluginIdfa());
  }
}
```

## Customize IDFA Plugin Initialization

To delay the `IDFA Plugin` initialization (ie. to avoid race condition with push notification prompt) implement the following:

```dart
import 'package:hightouch_events/client.dart';
import 'package:hightouch_events_plugin_idfa/plugin_idfa.dart'
    show PluginIdfa;

const writeKey = 'WRITE_KEY';

class _MyAppState extends State<MyApp> {
  final analytics = createClient(Configuration(writeKey));

  @override
  void initState() {
    // ...

    final idfaPlugin = PluginIdfa(shouldAskPermission: false);

    analytics
        .addPlugin(idfaPlugin);

    // ...

    idfaPlugin.requestTrackingPermission().then((enabled) {
      /**  ... */
    });
  }
}
```
