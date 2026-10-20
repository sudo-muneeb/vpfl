// Native media_kit subtitle probe. Run with `dart run`, outside Flutter UI.
// The pinned media_kit starts with vid=no until a VideoController attaches;
// this harness enables video decoding via the documented NativePlayer adapter.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:media_kit/media_kit.dart';

typedef Json = Map<String, dynamic>;

bool sameBytes(Uint8List left, Uint8List right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

List<SubtitleTrack> realTracks(Player player) => player.state.tracks.subtitle
    .where((track) => track.id != 'auto' && track.id != 'no')
    .toList();

Json trackJson(SubtitleTrack track) => {
  'id': track.id,
  'title': track.title,
  'language': track.language,
  'codec': track.codec,
  'default': track.isDefault,
  'uri': track.uri,
};

Future<void> until(
  String label,
  Future<bool> Function() ready, {
  Duration timeout = const Duration(seconds: 8),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!await ready()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('$label did not become ready', timeout);
    }
    // media_kit does not expose an event stream for arbitrary mpv properties.
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}

Json sourceFor(Json manifest, String id) => (manifest['sources'] as List)
    .cast<Json>()
    .singleWhere((entry) => entry['id'] == id);

Json videoFor(Json manifest, String id) => (manifest['videos'] as List)
    .cast<Json>()
    .singleWhere((entry) => entry['id'] == id);

Map<String, double> sampleTimes(Json source) {
  final cues = (source['cues'] as List).cast<List>();
  final intervals =
      cues
          .map(
            (cue) => [(cue[0] as num).toDouble(), (cue[1] as num).toDouble()],
          )
          .toList()
        ..sort((a, b) => a[0].compareTo(b[0]));
  final merged = <List<double>>[];
  for (final interval in intervals) {
    if (merged.isNotEmpty && interval[0] <= merged.last[1]) {
      if (interval[1] > merged.last[1]) merged.last[1] = interval[1];
    } else {
      merged.add([...interval]);
    }
  }
  double? gap;
  for (var index = 0; index < merged.length - 1; index++) {
    if (merged[index + 1][0] - merged[index][1] >= 0.2) {
      gap = (merged[index][1] + merged[index + 1][0]) / 2;
      break;
    }
  }
  if (gap == null) throw StateError('${source['id']} has no cue gap');
  return {
    'before': intervals.first[0] / 2,
    'first': ((cues[0][0] as num) + (cues[0][1] as num)) / 2,
    'gap': gap,
    'second': ((cues[1][0] as num) + (cues[1][1] as num)) / 2,
    'last': ((cues.last[0] as num) + (cues.last[1] as num)) / 2,
  };
}

class NativeCase {
  final Player player;
  final NativePlayer native;
  final Directory folder;
  final Json result;
  late final StreamSubscription<PlayerLog> logSubscription;
  late final StreamSubscription<Tracks> tracksSubscription;
  late final StreamSubscription<Track> trackSubscription;
  final logSink = StringBuffer();
  final streamEvents = <Json>[];
  Uint8List? previousShown;
  String? previousExpected;

  NativeCase._(this.player, this.native, this.folder, this.result);

  static Future<NativeCase> create(Directory folder, Json result) async {
    final player = Player(
      configuration: const PlayerConfiguration(
        vo: 'null',
        libass: true,
        muted: true,
        logLevel: MPVLogLevel.debug,
      ),
    );
    final native = player.platform as NativePlayer;
    final context = NativeCase._(player, native, folder, result);
    context.logSubscription = player.stream.log.listen((entry) {
      context.logSink.writeln('${entry.level}: ${entry.text}');
    });
    context.tracksSubscription = player.stream.tracks.listen((event) {
      context.streamEvents.add({
        'stream': 'tracks',
        'subtitles': realTracks(player).map(trackJson).toList(),
      });
    });
    context.trackSubscription = player.stream.track.listen((event) {
      context.streamEvents.add({
        'stream': 'track',
        'requested_subtitle': trackJson(event.subtitle),
      });
    });
    await native.setProperty('vid', 'auto').timeout(const Duration(seconds: 8));
    await native.setProperty('ao', 'null').timeout(const Duration(seconds: 8));
    return context;
  }

  Future<String> property(String name) =>
      native.getProperty(name).timeout(const Duration(seconds: 8));

  Future<Json> properties() async {
    final values = <String, String>{};
    for (final name in [
      'sid',
      'sub-auto',
      'sub-delay',
      'sub-ass-override',
      'embeddedfonts',
      'sub-font-provider',
      'sub-ass',
      'pause',
    ]) {
      values[name] = await property(name);
    }
    return values;
  }

  Future<void> open(File file, int expectedTracks) async {
    await player
        .open(Media(file.absolute.path), play: false)
        .timeout(const Duration(seconds: 10));
    await until(
      'media ${file.path} and $expectedTracks subtitle tracks',
      () async {
        final path = await property('path');
        return path.endsWith(file.absolute.path) &&
            player.state.duration > Duration.zero &&
            realTracks(player).length == expectedTracks;
      },
    );
  }

  Future<void> select(SubtitleTrack track) async {
    await player.setSubtitleTrack(track).timeout(const Duration(seconds: 8));
    if (track.uri) {
      await until(
        'external subtitle track',
        () async =>
            realTracks(player)
                .any((item) => item.id != 'auto' && item.id != 'no'),
      );
    } else if (track.id == 'no') {
      await until('subtitle Off', () async => await property('sid') == 'no');
    } else if (track.id != 'auto') {
      await until(
        'selected ${track.id}',
        () async => await property('sid') == track.id,
      );
    }
  }

  Future<Json> capture(String label, double seconds, Json source) async {
    await player
        .seek(Duration(milliseconds: (seconds * 1000).round()))
        .timeout(const Duration(seconds: 8));
    await until('seek $seconds', () async {
      final value = double.tryParse(await property('time-pos'));
      return value != null && (value - seconds).abs() <= 0.13;
    });
    final shown = File('${folder.path}/$label-subtitles.png');
    final video = File('${folder.path}/$label-video.png');
    final expected = (source['cues'] as List)
        .cast<List>()
        .where(
          (cue) =>
              (cue[0] as num).toDouble() <= seconds &&
              seconds < (cue[1] as num).toDouble(),
        )
        .map((cue) => cue[2] as String)
        .join('\n');
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    Uint8List? withSub;
    Uint8List? withoutSub;
    var attempts = 0;
    while (true) {
      attempts++;
      withSub = await player
          .screenshot(format: 'image/png', includeLibassSubtitles: true)
          .timeout(const Duration(seconds: 8));
      withoutSub = await player
          .screenshot(format: 'image/png', includeLibassSubtitles: false)
          .timeout(const Duration(seconds: 8));
      if (withSub != null &&
          withSub.isNotEmpty &&
          withoutSub != null &&
          withoutSub.isNotEmpty) {
        final visible = !sameBytes(withSub, withoutSub);
        final changedCue =
            previousExpected != null &&
            previousExpected!.isNotEmpty &&
            expected.isNotEmpty &&
            previousExpected != expected;
        final fresh =
            !changedCue ||
            previousShown == null ||
            !sameBytes(withSub, previousShown!);
        if (visible == expected.isNotEmpty && fresh) break;
      }
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException(
          'rendered frame for $label at $seconds did not become ready '
          '(expected subtitle=${expected.isNotEmpty}, attempts=$attempts)',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    await shown.writeAsBytes(withSub);
    await video.writeAsBytes(withoutSub);
    previousShown = withSub;
    previousExpected = expected;
    final item = {
      'label': label,
      'seconds': seconds,
      'source': source['id'],
      'sub_text': await property('sub-text'),
      'sid': await property('sid'),
      'requested': trackJson(player.state.track.subtitle),
      'subtitles_png': shown.path,
      'video_png': video.path,
      'difference_png': '${folder.path}/$label-difference.png',
      'screenshot_attempts': attempts,
    };
    (result['captures'] as List).add(item);
    return item;
  }

  Future<void> close() async {
    result['stream_events'] = streamEvents;
    try {
      await player.dispose().timeout(const Duration(seconds: 8));
    } finally {
      await logSubscription.cancel();
      await tracksSubscription.cancel();
      await trackSubscription.cancel();
      final log = File('${folder.path}/media_kit.log');
      await log.writeAsString(logSink.toString());
      result['log'] = log.path;
    }
  }
}

class Suite {
  final Json manifest;
  final Directory fixtures;
  final Directory output;
  final List<Json> results = [];

  Suite(this.manifest, this.fixtures, this.output);

  File fixture(String relative) => File('${fixtures.path}/$relative');

  Future<void> runCase(
    String name,
    String fixtureName,
    Future<void> Function(NativeCase context) action,
  ) async {
    final folder = Directory('${output.path}/$name')
      ..createSync(recursive: true);
    final result = <String, dynamic>{
      'name': name,
      'fixture': fixtureName,
      'engine': 'media_kit',
      'status': 'pass',
      'captures': <Json>[],
    };
    NativeCase? context;
    try {
      context = await NativeCase.create(folder, result);
      await action(context).timeout(const Duration(seconds: 90));
      result['properties'] = await context.properties();
    } catch (error, stack) {
      result['status'] = 'fail';
      result['error'] = '$error';
      result['stack'] = '$stack';
    } finally {
      if (context != null) {
        try {
          await context.close();
        } catch (error) {
          result['status'] = 'fail';
          result['dispose_error'] = '$error';
        }
      }
    }
    results.add(result);
    File('${output.path}/raw-results.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(results)}\n',
    );
    stdout.writeln(
      '${result['status'].toString().toUpperCase()} media_kit $name'
      '${result['status'] == 'fail' ? ': ${result['error']}' : ''}',
    );
  }

  Future<void> embedded() async {
    for (final entry in (manifest['videos'] as List).cast<Json>()) {
      final expectedTracks = (entry['tracks'] as List).cast<Json>();
      for (final expected in expectedTracks) {
        final name = 'embedded_${entry['id']}_${expected['language']}';
        await runCase(name, entry['file'] as String, (context) async {
          await context.open(
            fixture(entry['file'] as String),
            expectedTracks.length,
          );
          final tracks = realTracks(context.player);
          context.result['tracks'] = tracks.map(trackJson).toList();
          context.result['initial_sid'] = await context.property('sid');
          context.result['initial_requested'] = trackJson(
            context.player.state.track.subtitle,
          );
          for (final track in expectedTracks) {
            if (tracks
                    .where((item) => item.language == track['language'])
                    .length !=
                1) {
              throw StateError('missing ${track['language']} among $tracks');
            }
          }
          await context.select(
            tracks.singleWhere(
              (track) => track.language == expected['language'],
            ),
          );
          final source = sourceFor(manifest, expected['source'] as String);
          for (final point in sampleTimes(source).entries) {
            await context.capture(point.key, point.value, source);
          }
        });
      }
    }
  }

  Future<void> external() async {
    for (final entry in (manifest['external'] as List).cast<Json>()) {
      final source = sourceFor(manifest, entry['source'] as String);
      if (source['valid'] == false) continue;
      final video = videoFor(manifest, entry['video'] as String);
      await runCase(entry['id'] as String, entry['file'] as String, (
        context,
      ) async {
        await context.open(fixture(video['file'] as String), 0);
        await context.select(
          SubtitleTrack.uri(
            fixture(entry['file'] as String).absolute.uri.toString(),
          ),
        );
        await until(
          'one external subtitle track',
          () async => realTracks(context.player).length == 1,
        );
        context.result['tracks'] = realTracks(context.player)
            .map(trackJson)
            .toList();
        for (final point in sampleTimes(source).entries) {
          await context.capture(point.key, point.value, source);
        }
        final markers = (source['markers'] as List?)?.cast<String>() ?? [];
        if (markers.any((marker) => marker.contains(r'\move('))) {
          final first =
              (source['cues'] as List)[(source['motion_cue_index'] as num?)
                          ?.toInt() ??
                      0]
                  as List;
          await context.capture(
            'move_start',
            (first[0] as num).toDouble() + 0.2,
            source,
          );
          await context.capture(
            'move_end',
            (first[1] as num).toDouble() - 0.2,
            source,
          );
        }
        if (markers.any((marker) => marker.contains(r'\t('))) {
          final second = (source['cues'] as List)[1] as List;
          await context.capture(
            'color_start',
            (second[0] as num).toDouble() + 0.2,
            source,
          );
          await context.capture(
            'color_end',
            (second[1] as num).toDouble() - 0.2,
            source,
          );
        }
      });
    }
  }

  Future<void> nearby() async {
    final nearby = manifest['nearby'] as Json;
    final sidecars = (nearby['sidecars'] as List).cast<Json>();
    await runCase('nearby_auto_and_repeat', nearby['video'] as String, (
      context,
    ) async {
      await context.open(fixture(nearby['video'] as String), 2);
      final tracks = realTracks(context.player);
      context.result['tracks'] = tracks.map(trackJson).toList();
      for (final key in ['exact', 'language_suffix']) {
        final sidecar = sidecars.singleWhere((entry) => entry['match'] == key);
        final track = tracks.singleWhere(
          (entry) => entry.title == (sidecar['file'] as String).split('/').last,
        );
        await context.select(track);
        final source = sourceFor(manifest, sidecar['source'] as String);
        await context.capture(key, sampleTimes(source)['first']!, source);
      }
      final exact = sidecars.singleWhere((entry) => entry['match'] == 'exact');
      final before = realTracks(context.player).length;
      final uri = fixture(exact['file'] as String).absolute.uri.toString();
      await context.select(SubtitleTrack.uri(uri));
      await until(
        'first repeated external load',
        () async => realTracks(context.player).length >= before + 1,
      );
      await context.select(SubtitleTrack.uri(uri));
      await until(
        'second repeated external load',
        () async => realTracks(context.player).length >= before + 2,
      );
      context.result['select_repeat_count'] =
          realTracks(context.player).length - before;
    });
  }

  Future<void> transitions() async {
    final entry = videoFor(manifest, 'multilingual');
    await runCase(
      'selection_seek_pause_source_switch',
      entry['file'] as String,
      (context) async {
        await context.open(fixture(entry['file'] as String), 3);
        final tracks = realTracks(context.player);
        context.result['tracks'] = tracks.map(trackJson).toList();
        context.result['initial_sid'] = await context.property('sid');
        context.result['initial_requested'] = trackJson(
          context.player.state.track.subtitle,
        );
        final expectedTracks = (entry['tracks'] as List).cast<Json>();
        for (final language in ['eng', 'urd', 'jpn']) {
          final track = tracks.singleWhere(
            (entry) => entry.language == language,
          );
          await context.select(track);
          final sourceId =
              expectedTracks.singleWhere(
                    (entry) => entry['language'] == language,
                  )['source']
                  as String;
          final source = sourceFor(manifest, sourceId);
          await context.capture(
            language,
            sampleTimes(source)['first']!,
            source,
          );
        }
        await context.select(
          tracks.singleWhere((track) => track.language == 'eng'),
        );
        final english = sourceFor(manifest, 'english');
        for (final point in [
          'first',
          'gap',
          'second',
          'before',
          'last',
          'first',
        ]) {
          await context.capture(
            'seek_${point}_${(context.result['captures'] as List).length}',
            sampleTimes(english)[point]!,
            english,
          );
        }
        await context.player.play().timeout(const Duration(seconds: 8));
        await until(
          'resumed playback',
          () async => await context.property('pause') == 'no',
        );
        await context.player.pause().timeout(const Duration(seconds: 8));
        await until(
          'paused playback',
          () async => await context.property('pause') == 'yes',
        );
        await context.capture(
          'paused_cue',
          sampleTimes(english)['first']!,
          english,
        );
        await context.select(SubtitleTrack.no());
        await context.capture('off', sampleTimes(english)['first']!, {
          'id': 'off',
          'cues': [],
        });
        await context.select(SubtitleTrack.auto());
        await context.capture('auto', sampleTimes(english)['first']!, english);
        await context.open(
          fixture(videoFor(manifest, 'plain')['file'] as String),
          0,
        );
        context.result['after_plain_tracks'] = realTracks(context.player)
            .map(trackJson)
            .toList();
        context.result['after_plain_sid'] = await context.property('sid');
        await context.open(fixture(entry['file'] as String), 3);
        context.result['after_reopen_tracks'] = realTracks(context.player)
            .map(trackJson)
            .toList();
      },
    );
  }

  Future<void> malformed() async {
    final invalid = (manifest['external'] as List).cast<Json>().singleWhere(
      (entry) =>
          sourceFor(manifest, entry['source'] as String)['valid'] == false,
    );
    final valid = (manifest['external'] as List).cast<Json>().firstWhere(
      (entry) =>
          sourceFor(manifest, entry['source'] as String)['codec'] == 'subrip' &&
          sourceFor(manifest, entry['source'] as String)['valid'] != false,
    );
    await runCase('malformed_then_recover', invalid['file'] as String, (
      context,
    ) async {
      await context.open(
        fixture(
          videoFor(manifest, invalid['video'] as String)['file'] as String,
        ),
        0,
      );
      await context.player
          .setSubtitleTrack(
            SubtitleTrack.uri(
              fixture(invalid['file'] as String).absolute.uri.toString(),
            ),
          )
          .timeout(const Duration(seconds: 8));
      context.result['malformed_tracks'] = realTracks(context.player)
          .map(trackJson)
          .toList();
      context.result['malformed_requested'] = trackJson(
        context.player.state.track.subtitle,
      );
      await context.select(
        SubtitleTrack.uri(
          fixture(valid['file'] as String).absolute.uri.toString(),
        ),
      );
      await until(
        'recovery track',
        () async => realTracks(context.player).isNotEmpty,
      );
      final source = sourceFor(manifest, valid['source'] as String);
      await context.capture('recovered', sampleTimes(source)['first']!, source);
    });
  }

  Future<List<Json>> run() async {
    await embedded();
    await external();
    await nearby();
    await transitions();
    await malformed();
    return results;
  }
}

Future<void> main(List<String> args) async {
  if (args.length != 3) {
    stderr.writeln(
      'usage: dart run scripts/ci/media_kit_subtitle_check.dart '
      '<subtitle-suite-dir> <manifest.json> <output-dir>',
    );
    exitCode = 2;
    return;
  }
  MediaKit.ensureInitialized();
  final fixtures = Directory(args[0]).absolute;
  final manifest = jsonDecode(File(args[1]).readAsStringSync()) as Json;
  final output = Directory(args[2]).absolute..createSync(recursive: true);
  final results = await Suite(manifest, fixtures, output).run();
  final maps = File('/proc/self/maps').readAsLinesSync();
  final libraries =
      maps
          .where(
            (line) =>
                RegExp(r'lib(mpv|ass|harfbuzz|fontconfig|fribidi)')
                    .hasMatch(line),
          )
          .map((line) => line.split(' ').last)
          .toSet()
          .toList()
        ..sort();
  File('${output.path}/native-libraries.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(libraries)}\n',
  );
  stdout.writeln(
    'media_kit: ${results.where((row) => row['status'] == 'pass').length}'
    '/${results.length} harness cases completed without exception',
  );
  if (results.any((row) => row['status'] == 'fail')) exitCode = 1;
}
