/// Converts mpv's signed delay in seconds to VPFL's integer milliseconds.
int subtitleDelayMillisecondsFromNative(String seconds) {
  final value = double.tryParse(seconds);
  if (value == null || !value.isFinite) {
    throw FormatException('Invalid native subtitle delay: $seconds');
  }
  return (value * 1000).round();
}

/// mpv accepts decimal seconds; three places represent whole milliseconds.
String subtitleDelayNativeValue(int milliseconds) =>
    (milliseconds / 1000).toStringAsFixed(3);

String subtitleDelayLabel(int milliseconds) {
  if (milliseconds == 0) return '0 ms';
  return '${milliseconds > 0 ? '+' : '−'}${milliseconds.abs()} ms';
}
