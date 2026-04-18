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

  static const _speeds = [0.5, 1.0, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _controller.play();
        }
      });
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_initialized)
              AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            else
              const CircularProgressIndicator(),

            if (_controlsVisible && _initialized)
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

    return Container(
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
            title: Text(title),
            elevation: 0,
            actions: [
              PopupMenuButton<double>(
                initialValue: speed,
                onSelected: onSpeedChanged,
                icon: Text('$speed×', style: const TextStyle(color: Colors.white)),
                itemBuilder: (_) => speeds.map((s) =>
                  PopupMenuItem(value: s, child: Text('$s×'))).toList(),
              ),
            ],
          ),
          Column(children: [
            VideoProgressIndicator(controller, allowScrubbing: true,
              colors: const VideoProgressColors(playedColor: Colors.white)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(fmt(pos), style: const TextStyle(color: Colors.white)),
                  IconButton(
                    icon: Icon(controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white, size: 36),
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
    );
  }
}
