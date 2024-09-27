# hightouch_events_plugin_firebase

`DestinationPlugin` for [Firebase](https://firebase.google.com). Wraps [`firebase_analytics`](https://pub.dev/packages/firebase_analytics).

## Installation

Manually add this package to your `pubspec.yaml` file.

```yaml
dependencies:
  hightouch_events_plugin_firebase:
    git:
      url: https://github.com/ht-sdks/events-sdk-flutter
      ref: main
      path: packages/plugins/plugin_firebase
```

You will then need to configure your Firebase settings as per the [core Firebase documentation](https://firebase.google.com/docs/flutter/setup?platform=web) by running:

```bash
flutterfire configure
```

This will create a `firebase_options.dart` file under your `lib` folder.

## Usage

Follow the [instructions for adding plugins](https://github.com/ht-sdks/events-sdk-flutter_#adding-plugins) on the main Analytics client:

In your code where you initialize the analytics client call the `.add(plugin)` method with an `FirebaseDestination` instance.

```dart
import 'firebase_options.dart';
import 'package:hightouch_events/client.dart';
import 'package:hightouch_events_plugin_firebase/plugin_firebase.dart'
    show FirebaseDestination;

const writeKey = 'WRITE_KEY';

class _MyAppState extends State<MyApp> {
  final analytics = createClient(Configuration(writeKey));

  @override
  void initState() {
    // ...

    analytics
        .addPlugin(FirebaseDestination(DefaultFirebaseOptions.currentPlatform));
  }
}
```
