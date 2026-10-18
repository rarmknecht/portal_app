import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart' show DurationRange;

/// Formats a duration as `m:ss`, or `h:mm:ss` once it reaches an hour.
String formatDuration(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
}

/// A thick, finger-friendly seek bar for the video player.
///
/// The whole [hitHeight] strip responds to touch, the track itself is
/// [trackHeight] tall, and a round thumb marks the position. Dragging shows
/// the target time in a bubble above the thumb and seeks once on release, so
/// scrubbing a long video does not fire a seek on every pixel. A tap seeks
/// straight to the tapped point.
class VideoSeekBar extends StatefulWidget {
  const VideoSeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.buffered = const [],
    this.onScrubbingChanged,
    this.trackHeight = 6,
    this.thumbRadius = 9,
    this.hitHeight = 48,
    this.playedColor = Colors.white,
    this.bufferedColor = Colors.white38,
    this.backgroundColor = Colors.white24,
  });

  final Duration position;
  final Duration duration;

  /// Ranges the player has buffered, as reported by the controller.
  final List<DurationRange> buffered;

  /// Called once with the target position when a tap or drag completes.
  final ValueChanged<Duration> onSeek;

  /// Called with `true` when a scrub starts and `false` when it ends.
  final ValueChanged<bool>? onScrubbingChanged;

  final double trackHeight;
  final double thumbRadius;

  /// Height of the touch target; the track is centred inside it.
  final double hitHeight;

  final Color playedColor;
  final Color bufferedColor;
  final Color backgroundColor;

  @override
  State<VideoSeekBar> createState() => _VideoSeekBarState();
}

class _VideoSeekBarState extends State<VideoSeekBar> {
  /// Fraction under the finger while scrubbing; null when idle.
  double? _scrub;

  bool get _enabled => widget.duration > Duration.zero;

  /// Horizontal inset so the thumb never clips at either end.
  double get _pad => widget.thumbRadius + 3;

  double _fractionAt(double dx, double width) {
    final usable = width - 2 * _pad;
    if (usable <= 0) return 0;
    return ((dx - _pad) / usable).clamp(0.0, 1.0);
  }

  Duration _durationAt(double fraction) => Duration(
      milliseconds: (fraction * widget.duration.inMilliseconds).round());

  void _tap(double dx, double width) =>
      widget.onSeek(_durationAt(_fractionAt(dx, width)));

  void _begin(double dx, double width) {
    final wasScrubbing = _scrub != null;
    setState(() => _scrub = _fractionAt(dx, width));
    if (!wasScrubbing) widget.onScrubbingChanged?.call(true);
  }

  void _move(double dx, double width) {
    if (_scrub == null) return;
    setState(() => _scrub = _fractionAt(dx, width));
  }

  void _commit() {
    final f = _scrub;
    if (f == null) return;
    setState(() => _scrub = null);
    widget.onScrubbingChanged?.call(false);
    widget.onSeek(_durationAt(f));
  }

  void _cancel() {
    if (_scrub == null) return;
    setState(() => _scrub = null);
    widget.onScrubbingChanged?.call(false);
  }

  /// Step used by accessibility increase/decrease actions.
  static const _nudgeStep = Duration(seconds: 10);

  Duration _clampToVideo(Duration d) {
    if (d < Duration.zero) return Duration.zero;
    if (d > widget.duration) return widget.duration;
    return d;
  }

  void _nudge(Duration delta) =>
      widget.onSeek(_clampToVideo(widget.position + delta));

  @override
  Widget build(BuildContext context) {
    final totalMs = widget.duration.inMilliseconds;
    final played = _scrub ??
        (totalMs > 0
            ? (widget.position.inMilliseconds / totalMs).clamp(0.0, 1.0)
            : 0.0);
    final bufferedMs = widget.buffered
        .map((r) => r.end.inMilliseconds)
        .fold<int>(0, math.max);
    final buffered =
        totalMs > 0 ? (bufferedMs / totalMs).clamp(0.0, 1.0) : 0.0;
    final scrubbing = _scrub != null;

    return SizedBox(
      height: widget.hitHeight,
      child: LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth;
        final thumbX = _pad + played * (width - 2 * _pad);
        const bubbleWidth = 84.0;

        return Semantics(
          slider: true,
          label: 'Seek',
          value: formatDuration(widget.position),
          increasedValue: formatDuration(_clampToVideo(widget.position + _nudgeStep)),
          decreasedValue: formatDuration(_clampToVideo(widget.position - _nudgeStep)),
          enabled: _enabled,
          onIncrease: _enabled ? () => _nudge(_nudgeStep) : null,
          onDecrease: _enabled ? () => _nudge(-_nudgeStep) : null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: _enabled ? (d) => _tap(d.localPosition.dx, width) : null,
            onHorizontalDragStart:
                _enabled ? (d) => _begin(d.localPosition.dx, width) : null,
            onHorizontalDragUpdate:
                _enabled ? (d) => _move(d.localPosition.dx, width) : null,
            onHorizontalDragEnd: _enabled ? (_) => _commit() : null,
            onHorizontalDragCancel: _enabled ? _cancel : null,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SeekBarPainter(
                      played: played,
                      buffered: buffered,
                      pad: _pad,
                      trackHeight:
                          scrubbing ? widget.trackHeight * 1.5 : widget.trackHeight,
                      thumbRadius:
                          scrubbing ? widget.thumbRadius * 1.3 : widget.thumbRadius,
                      showThumb: _enabled,
                      playedColor: widget.playedColor,
                      bufferedColor: widget.bufferedColor,
                      backgroundColor: widget.backgroundColor,
                    ),
                  ),
                ),
                if (scrubbing)
                  Positioned(
                    left: (thumbX - bubbleWidth / 2)
                        .clamp(0.0, math.max(0.0, width - bubbleWidth)),
                    top: -40,
                    width: bubbleWidth,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xE6000000),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          formatDuration(_durationAt(_scrub!)),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _SeekBarPainter extends CustomPainter {
  const _SeekBarPainter({
    required this.played,
    required this.buffered,
    required this.pad,
    required this.trackHeight,
    required this.thumbRadius,
    required this.showThumb,
    required this.playedColor,
    required this.bufferedColor,
    required this.backgroundColor,
  });

  final double played;
  final double buffered;
  final double pad;
  final double trackHeight;
  final double thumbRadius;
  final bool showThumb;
  final Color playedColor;
  final Color bufferedColor;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final left = pad;
    final right = size.width - pad;
    final usable = math.max(0.0, right - left);
    final radius = Radius.circular(trackHeight / 2);

    RRect track(double fraction) => RRect.fromLTRBR(
        left, cy - trackHeight / 2, left + usable * fraction, cy + trackHeight / 2, radius);

    canvas.drawRRect(track(1), Paint()..color = backgroundColor);
    if (buffered > 0) {
      canvas.drawRRect(track(buffered), Paint()..color = bufferedColor);
    }
    if (played > 0) {
      canvas.drawRRect(track(played), Paint()..color = playedColor);
    }

    if (showThumb) {
      final center = Offset(left + usable * played, cy);
      canvas.drawCircle(
          center, thumbRadius + 1.5, Paint()..color = const Color(0x66000000));
      canvas.drawCircle(center, thumbRadius, Paint()..color = playedColor);
    }
  }

  @override
  bool shouldRepaint(_SeekBarPainter old) =>
      old.played != played ||
      old.buffered != buffered ||
      old.pad != pad ||
      old.trackHeight != trackHeight ||
      old.thumbRadius != thumbRadius ||
      old.showThumb != showThumb ||
      old.playedColor != playedColor ||
      old.bufferedColor != bufferedColor ||
      old.backgroundColor != backgroundColor;
}
