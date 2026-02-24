mkdir -p ios/Classes
mkdir -p android/main/kotlin

flutter pub run pigeon \
  --input pigeon/context.dart \
  --dart_out lib/native_context.dart \
  --swift_out ios/Classes/Context.swift \
  --kotlin_out android/src/main/kotlin/com/hightouch/events/Context.kt \
  --java_package "com.hightouch.events" \
  --kotlin_package "com.hightouch.events"
