## 1.0.4

- Fixed `TypeError: type 'Null' is not a subtype of type 'String'` crash in `DeepLinkData.fromJson` when `referringApplication` is null in the deep link event payload from Android
- Made `referringApplication` nullable to accurately represent cases where the referring app is unknown
- Added defensive error handling around deep link event processing

## 1.0.3

- Fixed nullable receiver issue for applicationInfo on Android API 33+

## 1.0.2

- Updated dependencies to latest versions
- Fixed flutter_fgbg API breaking change (FGBGEvents.stream → FGBGEvents.instance.stream)
- Code style modernization for flutter_lints 6.0

## 1.1.0

- Cleared out malformed files on error and reduced chance of files not writing completely if program exits prematurely
- Fixed podspec name
- Token added to device context
- Fixed route name on ScreenObserver
- Add flag to disable data storage

## 1.0.2

- Fixed an issue with EU Workspaces not respecting the proper apiHost

## 1.0.1

- Fix cocoapods

## 1.0.0

- iOS, Android, Web, and MacOS support
- Firebase, Adjust, and Appsflyer destination plugins
- adverising_id and IDFA enrichment plugins
- All event types supported (track, identify, screen, alias, group)
- Automatic Screen events
- Application life-cycle capture
- Customisable Flushing policies
- Customisable logging and error reporting
- Customisable HTTP (CDN) client
- Unit tested (although not all parts)
- Strongly typed, including User Traits and Context objects and plugin settings
- Fully asynchronous and concurrency safe state and persistence management
- Example app showing off usage of the SDK
