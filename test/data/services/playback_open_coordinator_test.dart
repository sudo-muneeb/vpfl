import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vpfl/data/services/playback_open_coordinator.dart';

void main() {
  test('drops queued source requests superseded before they start', () async {
    final PlaybackOpenCoordinator coordinator = PlaybackOpenCoordinator();
    final Completer<void> releaseFirst = Completer<void>();
    final Completer<void> firstStarted = Completer<void>();
    final List<String> opened = [];

    final Future<void> first = coordinator.run(() {
      opened.add('first');
      firstStarted.complete();
      return releaseFirst.future;
    });
    await firstStarted.future;

    final Future<void> superseded = coordinator.run(() async {
      opened.add('superseded');
    });
    final Future<void> latest = coordinator.run(() async {
      opened.add('latest');
    });

    releaseFirst.complete();
    await Future.wait([first, superseded, latest]);

    expect(opened, ['first', 'latest']);
  });

  test(
    'does not surface an error from a source superseded while opening',
    () async {
      final PlaybackOpenCoordinator coordinator = PlaybackOpenCoordinator();
      final Completer<void> releaseFirst = Completer<void>();
      final Completer<void> firstStarted = Completer<void>();

      final Future<void> staleFailure = coordinator.run(() async {
        firstStarted.complete();
        await releaseFirst.future;
        throw StateError('stale source failed');
      });
      await firstStarted.future;

      final Future<void> latest = coordinator.run(() async {});
      releaseFirst.complete();

      await Future.wait([staleFailure, latest]);
    },
  );

  test('cancel drops queued opens and close rejects later work', () async {
    final coordinator = PlaybackOpenCoordinator();
    final started = Completer<void>();
    final release = Completer<void>();
    var opened = 0;
    final first = coordinator.run(() async {
      started.complete();
      await release.future;
      opened++;
    });
    await started.future;
    final queued = coordinator.run(() async => opened++);
    final drained = coordinator.cancelPending();
    release.complete();
    await Future.wait([first, queued, drained]);
    expect(opened, 1);
    await coordinator.close();
    await expectLater(coordinator.run(() async => opened++), throwsStateError);
    expect(opened, 1);
  });
}
