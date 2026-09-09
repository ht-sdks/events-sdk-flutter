mkdir -p ios/hightouch_events_plugin_idfa/Sources/hightouch_events_plugin_idfa

flutter pub run pigeon \
  --input pigeon/idfa.dart \
  --dart_out lib/native_idfa.dart \
  --experimental_swift_out ios/hightouch_events_plugin_idfa/Sources/hightouch_events_plugin_idfa/Idfa.swift