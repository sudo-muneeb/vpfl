import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:vpfl/data/services/queue_progression.dart';

void main() {
  for (final shuffle in [false, true]) {
    for (final mode in PlaylistMode.values) {
      test('completion: shuffle=$shuffle repeat=$mode', () {
        final queue = QueueProgression(random: Random(7))..reset(4, 0);
        queue.setShuffle(shuffle);
        queue.repeat = mode;
        final played = <int>[queue.index];
        if (mode == PlaylistMode.single) {
          expect(queue.complete(), 0);
          expect(queue.complete(), 0);
          expect(queue.index, 0);
          return;
        }
        for (var i = 0; i < 3; i++) {
          played.add(queue.complete()!);
        }
        expect(played.toSet(), {0, 1, 2, 3});
        if (!shuffle) expect(played, [0, 1, 2, 3]);
        expect(
          queue.complete(),
          mode == PlaylistMode.none ? null : isNot(played.last),
        );
        if (mode == PlaylistMode.loop && !shuffle) expect(queue.index, 0);
      });
    }
  }

  test(
    'shuffle repeats full, freshly generated cycles without boundary replay',
    () {
      final queue = QueueProgression(random: Random(11))..reset(6, 2);
      queue
        ..setShuffle(true)
        ..repeat = PlaylistMode.loop;
      var last = queue.index;
      for (var cycle = 0; cycle < 3; cycle++) {
        final seen = <int>{last};
        for (var i = 0; i < 5; i++) {
          final next = queue.complete()!;
          expect(seen.add(next), isTrue);
          last = next;
        }
        expect(seen, {0, 1, 2, 3, 4, 5});
        final nextCycle = queue.complete()!;
        expect(nextCycle, isNot(last));
        last = nextCycle;
      }
    },
  );

  test('previous retraces indices and next reuses the same traversal', () {
    final queue = QueueProgression(random: Random(3))..reset(5, 1);
    queue.setShuffle(true);
    final first = queue.next()!;
    final second = queue.next()!;
    expect(queue.previous(), first);
    expect(queue.previous(), 1);
    expect(queue.next(), first);
    expect(queue.next(), second);
  });

  test('toggling shuffle retains the current index and restores sequence', () {
    final queue = QueueProgression(random: Random(4))..reset(5, 2);
    queue.setShuffle(true);
    final shuffled = queue.next()!;
    queue.setShuffle(false);
    expect(queue.index, shuffled);
    expect(queue.next(), shuffled == 4 ? null : shuffled + 1);
    queue.setShuffle(true);
    expect(queue.index, shuffled == 4 ? 4 : shuffled + 1);
  });

  test('enabling shuffle mid-cycle excludes items already played', () {
    final queue = QueueProgression(random: Random(5))..reset(5, 0);
    expect(queue.complete(), 1);
    expect(queue.complete(), 2);
    queue.setShuffle(true);
    expect({queue.complete(), queue.complete()}, {3, 4});
    expect(queue.complete(), null);
  });

  test('repeat changes take effect without resetting shuffle order', () {
    final queue = QueueProgression(random: Random(2))..reset(3, 0);
    queue.setShuffle(true);
    final first = queue.next()!;
    queue.repeat = PlaylistMode.single;
    expect(queue.complete(), first);
    queue.repeat = PlaylistMode.none;
    final second = queue.complete()!;
    expect({first, second}, hasLength(2));
    expect(queue.complete(), null);
  });

  test('single item never enables shuffle and repeat one replays it', () {
    final queue = QueueProgression(random: Random(1))..reset(1, 0);
    queue.setShuffle(true);
    expect(queue.shuffle, isFalse);
    expect(queue.canNext, isFalse);
    expect(queue.complete(), null);
    queue.repeat = PlaylistMode.single;
    expect(queue.complete(), 0);
    queue.repeat = PlaylistMode.loop;
    expect(queue.complete(), 0);
  });

  test('duplicate URIs are separate positions in the logical queue', () {
    final uris = ['a.mp4', 'a.mp4', 'b.mp4'];
    final queue = QueueProgression(random: Random(1))..reset(uris.length, 0);
    expect(queue.complete(), 1);
    expect(uris[queue.index], uris[0]);
    expect(queue.complete(), 2);
  });

  test('reset and clear invalidate old traversal', () {
    final queue = QueueProgression(random: Random(1))..reset(4, 0);
    queue.setShuffle(true);
    queue.next();
    queue.reset(2, 1);
    expect(queue.index, 1);
    queue.clear();
    expect(queue.complete(), null);
    expect(queue.canNext, isFalse);
  });
}
