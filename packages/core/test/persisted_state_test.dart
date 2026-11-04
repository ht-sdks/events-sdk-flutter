import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hightouch_events/errors.dart';
import 'package:hightouch_events/state.dart';

import 'helpers/memory_store.dart';

class _FailingWriteStore extends MemoryStore {
  @override
  Future<void> setPersisted(String key, Map<String, dynamic> value) async {
    throw Exception("No space left on device (errno 28)");
  }
}

void main() {
  test('disk-full write error is routed to the error handler, not left unhandled', () async {
    final errors = <Object>[];
    final unhandled = <Object>[];

    await runZonedGuarded(() async {
      final state = FiltersState(_FailingWriteStore());
      state.init((e) => errors.add(e), true);
      await state.ready;
      state.setState({});
      await Future.delayed(const Duration(milliseconds: 50));
    }, (e, _) => unhandled.add(e));

    expect(unhandled, isEmpty);
    expect(errors, isNotEmpty);
    expect(errors.first, isA<StorageUnableToWrite>());
  });
}
