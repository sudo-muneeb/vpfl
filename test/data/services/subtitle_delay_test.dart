import 'package:flutter_test/flutter_test.dart';
import 'package:vpfl/data/services/subtitle_delay.dart';

void main() {
  test('native seconds round to signed whole milliseconds', () {
    for (final (native, expected) in [
      ('0.000000', 0),
      ('0.100000', 100),
      ('-0.100000', -100),
      ('1.234567', 1235),
      ('-5.000000', -5000),
    ]) {
      expect(subtitleDelayMillisecondsFromNative(native), expected);
    }
    for (final invalid in ['', 'NaN', 'Infinity', 'not a number']) {
      expect(
        () => subtitleDelayMillisecondsFromNative(invalid),
        throwsFormatException,
      );
    }
  });

  test('integer steps serialize to decimal seconds without drift', () {
    var milliseconds = 0;
    for (var step = 0; step < 50; step++) {
      milliseconds = subtitleDelayMillisecondsFromNative(
        subtitleDelayNativeValue(milliseconds + 100),
      );
    }
    expect(milliseconds, 5000);
    expect(subtitleDelayNativeValue(milliseconds), '5.000');
    for (var step = 0; step < 100; step++) {
      milliseconds = subtitleDelayMillisecondsFromNative(
        subtitleDelayNativeValue(milliseconds - 100),
      );
    }
    expect(milliseconds, -5000);
    expect(subtitleDelayNativeValue(milliseconds), '-5.000');
    expect(subtitleDelayLabel(milliseconds), '−5000 ms');
    expect(subtitleDelayLabel(100), '+100 ms');
    expect(subtitleDelayLabel(0), '0 ms');
  });
}
