# hightouch_events_plugin_adjust

`DestinationPlugin` for [Adjust](https://www.adjust.com/). Wraps [`adjust_sdk`](https://pub.dev/packages/adjust_sdk).

## Installation

Manually add this package to your `pubspec.yaml` file.

```yaml
dependencies:
  hightouch_events_plugin_adjust:
    git:
      url: https://github.com/ht-sdks/events-sdk-flutter
      ref: main
      path: packages/plugins/plugin_adjust
```

## Usage

Follow the [instructions for adding plugins](https://github.com/ht-sdks/events-sdk-flutter_#adding-plugins) on the main Analytics client:

In your code where you initialize the analytics client call the `.add(plugin)` method with an `AdjustDestination` instance.

```dart
import 'package:hightouch_events/client.dart';
import 'package:hightouch_events_plugin_adjust/plugin_adjust.dart'
    show AdjustDestination;

const writeKey = 'WRITE_KEY';

class _MyAppState extends State<MyApp> {
  final analytics = createClient(Configuration(writeKey));

  @override
  void initState() {
    // ...

    analytics
        .addPlugin(AdjustDestination());
  }
}
```
