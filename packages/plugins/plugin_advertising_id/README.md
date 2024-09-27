# hightouch_events_plugin_advertising_id

`EnrichmentPlugin` to collect advertisingId on Android

## Installation

Manually add this package to your `pubspec.yaml` file.

```yaml
dependencies:
  hightouch_events_plugin_advertising_id:
    git:
      url: https://github.com/ht-sdks/events-sdk-flutter
      ref: main
      path: packages/plugins/plugin_advertising_id
```

This plugin requires a `compileSdkVersion` of at least 19.

See [Google Play Services documentation](https://developers.google.com/admob/android/quick-start) for `advertisingId` setup

## Usage

Follow the [instructions for adding plugins](https://github.com/ht-sdks/events-sdk-flutter_#adding-plugins) on the main Analytics client:

In your code where you initialize the analytics client call the `.add(plugin)` method with an `AdvertisingIdDestination` instance.

```dart
import 'package:hightouch_events/client.dart';
import 'package:hightouch_events_plugin_advertising_id/plugin_advertising_id.dart'
    show PluginAdvertisingId;

const writeKey = 'WRITE_KEY';

class _MyAppState extends State<MyApp> {
  final analytics = createClient(Configuration(writeKey));

  @override
  void initState() {
    // ...

    analytics
        .addPlugin(PluginAdvertisingId());
  }
}
```

## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.
