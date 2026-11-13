import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hightouch_events/errors.dart';
import 'package:hightouch_events/state.dart';
import 'package:mockito/mockito.dart';

import 'mocks/mocks.dart';
import 'mocks/mocks.mocks.dart';

final _diskFull = Exception("No space left on device (errno 28)");

MockStore _store({Future<Map<String, dynamic>?> Function()? onGet, required Future Function(int call) onSet}) {
  final store = Mocks.store();
  var setCalls = 0;
  when(store.ready).thenAnswer((_) => Future.value());
  when(store.getPersisted(any)).thenAnswer((_) => onGet != null ? onGet() : Future.value(null));
  when(store.setPersisted(any, any)).thenAnswer((_) => onSet(++setCalls));
  return store;
}

void main() {
  test('disk-full write error is routed to the error handler, not left unhandled', () async {
    final errors = <Object>[];
    final unhandled = <Object>[];

    await runZonedGuarded(() async {
      final state = FiltersState(_store(onSet: (_) => Future.error(_diskFull)));
      state.init((e) => errors.add(e), true);
      await state.ready;
      state.setState({});
      await Future.delayed(const Duration(milliseconds: 50));
    }, (e, _) => unhandled.add(e));

    expect(unhandled, isEmpty);
    expect(errors, isNotEmpty);
    expect(errors.first, isA<StorageUnableToWrite>());
  });

  test('a failed in-flight write still lets the queued follow-up write run', () async {
    final errors = <Object>[];
    final unhandled = <Object>[];
    late final MockStore store;

    await runZonedGuarded(() async {
      // Created inside the guarded zone so the pending write's error is delivered within it.
      final firstWrite = Completer<void>();
      store = _store(onSet: (call) => call == 1 ? firstWrite.future : Future.value());

      final state = FiltersState(store);
      state.init((e) => errors.add(e), true);
      await state.ready;
      verify(store.setPersisted(any, any)).called(1); // initial write, still in flight

      state.setState({}); // marks a pending update while the first write is in flight
      firstWrite.completeError(_diskFull);
      await Future.delayed(const Duration(milliseconds: 50));
    }, (e, _) => unhandled.add(e));

    expect(unhandled, isEmpty);
    expect(errors.whereType<StorageUnableToWrite>(), hasLength(1));
    verify(store.setPersisted(any, any)).called(1); // the follow-up write was still attempted
  });

  test('failure while cleaning up a corrupt file is reported, not unhandled', () async {
    final errors = <Object>[];
    final unhandled = <Object>[];

    await runZonedGuarded(() async {
      final store = _store(
        onGet: () => Future.error(const FormatException('bad json')),
        onSet: (_) => Future.error(_diskFull),
      );
      final state = FiltersState(store);
      state.init((e) => errors.add(e), false); // persistence off: only the cleanup write runs
      await state.ready;
      await Future.delayed(const Duration(milliseconds: 50));
    }, (e, _) => unhandled.add(e));

    expect(unhandled, isEmpty);
    expect(errors.whereType<ErrorLoadingStorage>(), hasLength(1));
    expect(errors.whereType<StorageUnableToWrite>(), hasLength(1));
  });
}
