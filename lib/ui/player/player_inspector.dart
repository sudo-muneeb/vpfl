import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../data/model/real_media_tracks.dart';
import '../../data/services/playback_service.dart';

enum InspectorMode { media, diagnostics }

/// Secondary file facts and live playback state, within the player surface.
class PlayerInspector extends StatefulWidget {
  const PlayerInspector({
    required this.playback,
    required this.uri,
    required this.renderingMode,
    required this.mode,
    required this.onModeChanged,
    required this.onClose,
    super.key,
  });

  final PlaybackService playback;
  final String? uri;
  final String? renderingMode;
  final InspectorMode mode;
  final ValueChanged<InspectorMode> onModeChanged;
  final VoidCallback onClose;

  @override
  State<PlayerInspector> createState() => _PlayerInspectorState();
}

class _PlayerInspectorState extends State<PlayerInspector> {
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  String? _hardwareDecoder;

  @override
  void initState() {
    super.initState();
    final playback = widget.playback;
    for (final stream in <Stream<dynamic>>[
      playback.tracksStream,
      playback.videoParamsStream,
      playback.audioParamsStream,
      playback.durationStream,
    ]) {
      _subscriptions.add(
        stream.listen((_) {
          if (mounted) setState(() {});
        }),
      );
    }
    for (final stream in <Stream<dynamic>>[
      playback.selectedTracksStream,
      playback.positionStream,
      playback.playingStream,
      playback.rateStream,
    ]) {
      _subscriptions.add(
        stream.listen((_) {
          if (mounted && widget.mode == InspectorMode.diagnostics) {
            setState(() {});
          }
        }),
      );
    }
    _subscriptions.add(
      playback.videoParamsStream.listen((_) {
        if (widget.mode == InspectorMode.diagnostics) {
          unawaited(_readHardwareDecoder());
        }
      }),
    );
    if (widget.mode == InspectorMode.diagnostics) {
      unawaited(_readHardwareDecoder());
    }
  }

  @override
  void didUpdateWidget(covariant PlayerInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri != widget.uri) {
      _hardwareDecoder = null;
      if (widget.mode == InspectorMode.diagnostics) {
        unawaited(_readHardwareDecoder());
      }
    } else if (oldWidget.mode != widget.mode &&
        widget.mode == InspectorMode.diagnostics) {
      unawaited(_readHardwareDecoder());
    }
  }

  Future<void> _readHardwareDecoder() async {
    final uri = widget.uri;
    final value = await widget.playback.hardwareDecoder();
    if (mounted && uri == widget.uri && value != _hardwareDecoder) {
      setState(() => _hardwareDecoder = value);
    }
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playback = widget.playback;
    final tracks = RealMediaTracks(playback.tracks);
    final foreground = Theme.of(context).colorScheme.onSurface;
    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
      elevation: 10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 8, 2),
            child: Row(
              children: [
                Text('Info', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  tooltip: 'Close info',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                for (final mode in InspectorMode.values)
                  Expanded(
                    child: TextButton(
                      onPressed: () => widget.onModeChanged(mode),
                      style: TextButton.styleFrom(
                        backgroundColor: widget.mode == mode
                            ? Theme.of(context).colorScheme.surfaceContainerHigh
                            : null,
                      ),
                      child: Text(
                        mode == InspectorMode.media ? 'Media' : 'Diagnostics',
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: widget.mode == InspectorMode.media
                  ? _mediaRows(context, playback, tracks)
                  : _diagnosticRows(context, playback, tracks),
            ),
          ),
          Divider(height: 1, color: foreground.withValues(alpha: 0.14)),
        ],
      ),
    );
  }

  List<Widget> _mediaRows(
    BuildContext context,
    PlaybackService playback,
    RealMediaTracks tracks,
  ) {
    final uri = widget.uri;
    final parsed = uri == null ? null : Uri.tryParse(uri);
    final location = parsed?.scheme == 'file' ? parsed!.toFilePath() : uri;
    final filename = parsed?.pathSegments.lastOrNull;
    return [
      if (filename != null) _fact(context, 'File', filename),
      if (location != null) _fact(context, 'Location', location),
      if (playback.duration > Duration.zero)
        _fact(context, 'Duration', _duration(playback.duration)),
      if (tracks.video.isNotEmpty) _heading(context, 'Video'),
      for (var i = 0; i < tracks.video.length; i++)
        _fact(
          context,
          tracks.video.length == 1 ? 'Video' : 'Video ${i + 1}',
          _videoDetails(
                tracks.video[i],
                tracks.video.length == 1 ? playback.videoParams : null,
              ) ??
              'Stream ${tracks.video[i].id}',
        ),
      if (tracks.audio.isNotEmpty) _heading(context, 'Audio'),
      for (var i = 0; i < tracks.audio.length; i++)
        _fact(
          context,
          tracks.audio.length == 1 ? 'Audio' : 'Audio ${i + 1}',
          _audioDetails(
                tracks.audio[i],
                tracks.audio.length == 1 ? playback.audioParams : null,
              ) ??
              'Stream ${tracks.audio[i].id}',
        ),
      if (tracks.video.isNotEmpty || tracks.audio.isNotEmpty)
        _heading(context, 'Subtitles'),
      if (tracks.subtitle.isEmpty &&
          (tracks.video.isNotEmpty || tracks.audio.isNotEmpty))
        _fact(context, 'Subtitles', 'None'),
      for (var i = 0; i < tracks.subtitle.length; i++)
        _fact(
          context,
          tracks.subtitle.length == 1 ? 'Subtitle' : 'Subtitle ${i + 1}',
          _subtitleDetails(tracks.subtitle[i]),
        ),
    ];
  }

  List<Widget> _diagnosticRows(
    BuildContext context,
    PlaybackService playback,
    RealMediaTracks tracks,
  ) {
    final selectedVideo = tracks.activeVideo(playback.selectedTracks.video.id);
    final selectedAudio = tracks.activeAudio(playback.selectedTracks.audio.id);
    return [
      if (widget.renderingMode != null)
        _fact(context, 'Rendering', switch (widget.renderingMode) {
          'gpu' => 'GPU rendering',
          'software' => 'Software rendering',
          'initializing' => 'Initializing',
          _ => 'Unavailable',
        }),
      _fact(context, 'Playback', playback.isPlaying ? 'Playing' : 'Paused'),
      _fact(context, 'Position', _duration(playback.position)),
      _fact(context, 'Playback rate', '${playback.rate}×'),
      if (_hardwareDecoder != null)
        _fact(
          context,
          'Hardware decoding',
          _hardwareDecoder == 'no' ? 'Software' : _hardwareDecoder!,
        ),
      if (selectedVideo != null) ...[
        _heading(context, 'Video'),
        if (mediaCodec(selectedVideo.codec) case final codec?)
          _fact(context, 'Codec', codec),
        if (mediaResolution(playback.videoParams.w, playback.videoParams.h)
            case final resolution?)
          _fact(context, 'Resolution', resolution),
        if (selectedVideo.fps case final fps?)
          _fact(context, 'Frame rate', '${fps.toStringAsFixed(2)} fps'),
      ],
      if (selectedAudio != null) ...[
        _heading(context, 'Audio'),
        if (mediaCodec(selectedAudio.codec) case final codec?)
          _fact(context, 'Codec', codec),
        if (playback.audioParams.hrChannels ?? playback.audioParams.channels
            case final channels?)
          _fact(context, 'Channels', channels),
        if (playback.audioParams.sampleRate case final rate?)
          _fact(context, 'Sample rate', '${rate / 1000} kHz'),
      ],
    ];
  }

  String? _videoDetails(VideoTrack track, VideoParams? params) {
    final values = <String>[
      ?mediaTechnicalSummary(
        track.codec,
        track.w ?? params?.w,
        track.h ?? params?.h,
        fps: track.fps,
      ),
      ?track.decoder,
      if (track.bitrate case final bitrate?) _bitrate(bitrate),
      ?track.language,
      ?track.title,
    ];
    return values.isEmpty ? null : values.join('\n');
  }

  String? _audioDetails(AudioTrack track, AudioParams? params) {
    final values = <String>[
      ?mediaCodec(track.codec),
      ?track.decoder,
      ?(track.channels ?? params?.hrChannels ?? params?.channels),
      if (track.channelscount ?? params?.channelCount case final count?)
        '$count channels',
      if (track.samplerate ?? params?.sampleRate case final rate?)
        '${rate / 1000} kHz',
      if (track.bitrate case final bitrate?) _bitrate(bitrate),
      ?track.language,
      ?track.title,
    ];
    return values.isEmpty ? null : values.join('\n');
  }

  String _subtitleDetails(SubtitleTrack track) {
    final values = <String>[
      ?mediaCodec(track.codec),
      ?track.language,
      ?track.title,
      if (track.uri || track.data) 'External',
    ];
    return values.isEmpty ? 'Stream ${track.id}' : values.join(' · ');
  }

  String _bitrate(int bitsPerSecond) => bitsPerSecond >= 1000000
      ? '${(bitsPerSecond / 1000000).toStringAsFixed(1)} Mb/s'
      : '${(bitsPerSecond / 1000).round()} kb/s';

  String _duration(Duration value) {
    final minutes = (value.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
    return value.inHours > 0
        ? '${value.inHours}:$minutes:$seconds'
        : '$minutes:$seconds';
  }

  Widget _heading(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );

  Widget _fact(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 2),
        SelectableText(value, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}
