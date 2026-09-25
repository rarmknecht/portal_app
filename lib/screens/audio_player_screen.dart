import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

class AudioPlayerScreen extends StatefulWidget {
  final String url;
  final Map<String, String> headers;

  /// Stable, non-secret identifier for the Android media session. The
  /// session's metadata is readable by other apps, so it must never be the
  /// URL with credentials in it.
  final String mediaId;
  final String title;

  const AudioPlayerScreen({
    super.key,
    required this.url,
    required this.mediaId,
    required this.title,
    this.headers = const {},
  });

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  // ExoPlayer sends request headers itself; no local proxy needed.
  final _player = AudioPlayer(useProxyForRequestHeaders: false);
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(widget.url),
          headers: widget.headers.isEmpty ? null : widget.headers,
          tag: MediaItem(
            id: widget.mediaId,
            title: widget.title,
          ),
        ),
      );
      await _player.play();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = '$e'; });
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration? d) {
    if (d == null) return '--:--';
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Playback error: $_error'))
              : Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.music_note, size: 96),
                      const SizedBox(height: 24),
                      Text(widget.title,
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center),
                      const SizedBox(height: 32),

                      StreamBuilder<Duration?>(
                        stream: _player.positionStream,
                        builder: (context, snap) {
                          final pos = snap.data ?? Duration.zero;
                          final dur = _player.duration;
                          return Column(children: [
                            Slider(
                              value: dur != null && dur.inMilliseconds > 0
                                  ? pos.inMilliseconds / dur.inMilliseconds
                                  : 0,
                              onChanged: dur != null
                                  ? (v) => _player.seek(
                                      Duration(milliseconds: (v * dur.inMilliseconds).round()))
                                  : null,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_fmt(pos)),
                                Text(_fmt(dur)),
                              ],
                            ),
                          ]);
                        },
                      ),

                      const SizedBox(height: 16),
                      StreamBuilder<PlayerState>(
                        stream: _player.playerStateStream,
                        builder: (context, snap) {
                          final playing = snap.data?.playing ?? false;
                          return IconButton(
                            iconSize: 64,
                            icon: Icon(playing ? Icons.pause_circle : Icons.play_circle),
                            onPressed: () =>
                                playing ? _player.pause() : _player.play(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
    );
  }
}
