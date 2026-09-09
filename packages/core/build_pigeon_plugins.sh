mkdir -p ios/hightouch_events/Sources/hightouch_events
mkdir -p android/main/kotlin

flutter pub run pigeon \
  --input pigeon/context.dart \
  --dart_out lib/native_context.dart \
  --experimental_swift_out ios/hightouch_events/Sources/hightouch_events/Context.swift \
  --experimental_kotlin_out android/src/main/kotlin/com/hightouch/events/Context.kt \
  --java_package "com.hightouch.flutter"
