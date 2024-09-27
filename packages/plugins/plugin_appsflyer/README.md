# hightouch_events_plugin_appsflyer

`DestinationPlugin` for [Appsflyer](https://www.appsflyer.com/). Wraps [`appsflyer_sdk`](https://pub.dev/packages/appsflyer_sdk).

## Installation

Manually add this package to your `pubspec.yaml` file.

```yaml
dependencies:
  hightouch_events_plugin_appsflyer:
    git:
      url: https://github.com/ht-sdks/events-sdk-flutter
      ref: main
      path: packages/plugins/plugin_appsflyer
```

## Usage

Follow the [instructions for adding plugins](https://github.com/ht-sdks/events-sdk-flutter_#adding-plugins) on the main Analytics client:

In your code where you initialize the analytics client call the `.add(plugin)` method with an `AppsFlyerDestination` instance.

```dart
import 'package:hightouch_events/client.dart';
import 'package:hightouch_events_plugin_appsflyer/plugin_appsflyer.dart'
    show AppsFlyerDestination;

const writeKey = 'WRITE_KEY';

class _MyAppState extends State<MyApp> {
  final analytics = createClient(Configuration(writeKey));

  @override
  void initState() {
    // ...

    analytics
        .addPlugin(AppsFlyerDestination());
  }
}
```
