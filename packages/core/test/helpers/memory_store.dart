import 'package:hightouch_events/utils/store/store.dart';

class MemoryStore with Store {
  final Map<String, Map<String, dynamic>> _data;

  MemoryStore([Map<String, Map<String, dynamic>>? data]) : _data = data ?? {};

  @override
  Future<Map<String, dynamic>?> getPersisted(String key) async {
    final value = _data[key];
    return value == null ? null : Map<String, dynamic>.from(value);
  }

  @override
  Future<void> setPersisted(String key, Map<String, dynamic> value) async {
    _data[key] = Map<String, dynamic>.from(value);
  }

  @override
  Future<void> get ready => Future.value();

  @override
  void dispose() {}
}
