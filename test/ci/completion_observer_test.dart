import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/support/completion_observer.dart';

void main() {
  const attempt = CompletionAttempt('/video/a.mp4', 3, 0);
  CompletionEvent event({
    int generation = 3,
    String? queueSource = '/video/a.mp4',
    String? playerSource = '/video/a.mp4',
    Duration position = const Duration(milliseconds: 2375),
  }) => CompletionEvent(
    generation: generation,
    queueSource: queueSource,
    playerSource: playerSource,
    position: position,
    duration: const Duration(milliseconds: 2521),
  );

  test('natural EOF must belong to the current source and attempt', () {
    expect(attempt.reachedBy([event()]), isTrue);
    for (final (reason, events) in <(String, List<CompletionEvent>)>[
      ('stall or error stop without EOF', []),
      ('source replaced before EOF', [event(queueSource: '/video/b.mp4')]),
      ('media_kit source differs', [event(playerSource: '/video/b.mp4')]),
      ('old session EOF', [event(generation: 2)]),
      (
        'early completion',
        [event(position: const Duration(milliseconds: 700))],
      ),
    ]) {
      expect(attempt.reachedBy(events), isFalse, reason: reason);
    }
    expect(
      const CompletionAttempt('/video/a.mp4', 3, 1).reachedBy([event()]),
      isFalse,
      reason: 'an unrelated EOF before the attempt cannot count',
    );
  });
}
