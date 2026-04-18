import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String url;
  final String title;

  const VideoPlayerScreen({super.key, required this.url, required this.title});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _controlsVisible = true;
  double _playbackSpeed = 1.0;
  String? _error;

  static const _speeds = [0.5, 1.0, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller.addListener(_onControllerUpdate);
    try {
      await _controller.initialize();
      if (mounted) {
        setState(() => _initialized = true);
        _controller.play();
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load video: $e');
    }
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    if (_controller.value.hasError && _error == null) {
      setState(() => _error = _controller.value.errorDescription ?? 'Playback error');
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  void _toggleControls() => setState(() => _controlsVisible = !_controlsVisible);

  void _setSpeed(double speed) {
    setState(() => _playbackSpeed = speed);
    _controller.setPlaybackSpeed(speed);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: _error != null
            ? _ErrorView(title: widget.title, message: _error!)
            : _initialized
                ? GestureDetector(
                    onTap: _toggleControls,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: SizedBox(
                              width: _controller.value.size.width,
                              height: _controller.value.size.height,
                              child: VideoPlayer(_controller),
                            ),
                          ),
                        ),
                        if (_controlsVisible)
                          _Controls(
                            controller: _controller,
                            title: widget.title,
                            speed: _playbackSpeed,
                            speeds: _speeds,
                            onSpeedChanged: _setSpeed,
                            fmt: _fmt,
                          ),
                      ],
                    ),
                  )
                : _LoadingView(title: widget.title),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  final String title;
  const _LoadingView({required this.title});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 20),
              Text('Loading…', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
        SafeArea(
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String title;
  final String message;
  const _ErrorView({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_off, size: 64, color: Colors.white38),
          const SizedBox(height: 20),
          Text(title,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(message,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 28),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Go back'),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  final VideoPlayerController controller;
  final String title;
  final double speed;
  final List<double> speeds;
  final void Function(double) onSpeedChanged;
  final String Function(Duration) fmt;

  const _Controls({
    required this.controller,
    required this.title,
    required this.speed,
    required this.speeds,
    required this.onSpeedChanged,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final pos = controller.value.position;
    final dur = controller.value.duration;

    return SizedBox.expand(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xCC000000), Colors.transparent, Colors.transparent, Color(0xCC000000)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              title: Text(title),
              elevation: 0,
              actions: [
                PopupMenuButton<double>(
                  initialValue: speed,
                  onSelected: onSpeedChanged,
                  icon: Text('$speed×', style: const TextStyle(color: Colors.white)),
                  itemBuilder: (_) => speeds
                      .map((s) => PopupMenuItem(value: s, child: Text('$s×')))
                      .toList(),
                ),
              ],
            ),
            Column(children: [
              VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                colors: const VideoProgressColors(playedColor: Colors.white),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(fmt(pos), style: const TextStyle(color: Colors.white)),
                    IconButton(
                      icon: Icon(
                        controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 36,
                      ),
                      onPressed: () => controller.value.isPlaying
                          ? controller.pause()
                          : controller.play(),
                    ),
                    Text(fmt(dur), style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
