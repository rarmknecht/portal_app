import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart' show DurationRange;

import 'package:portal_app/widgets/video_seek_bar.dart';

void main() {
  group('formatDuration', () {
    test('minutes and seconds under an hour', () {
      expect(formatDuration(const Duration(seconds: 5)), '00:05');
      expect(formatDuration(const Duration(minutes: 7, seconds: 30)), '07:30');
    });

    test('hours once reached', () {
      expect(formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
          '1:02:03');
    });
  });

  group('VideoSeekBar', () {
    // 400 wide, thumbRadius 9 → pad 12, usable track 376 px.
    const width = 400.0;
    const duration = Duration(minutes: 10);
    final seeks = <Duration>[];
    final scrubStates = <bool>[];

    setUp(() {
      seeks.clear();
      scrubStates.clear();
    });

    Future<void> pump(WidgetTester tester,
        {Duration dur = duration,
        Duration position = const Duration(minutes: 1)}) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: VideoSeekBar(
                position: position,
                duration: dur,
                buffered: [DurationRange(Duration.zero, const Duration(minutes: 4))],
                onSeek: seeks.add,
                onScrubbingChanged: scrubStates.add,
              ),
            ),
          ),
        ),
      ));
    }

    testWidgets('is a tall touch target', (tester) async {
      await pump(tester);
      expect(tester.getSize(find.byType(VideoSeekBar)).height, 48);
    });

    testWidgets('tap seeks to the tapped point', (tester) async {
      await pump(tester);
      final bar = find.byType(VideoSeekBar);
      await tester.tapAt(tester.getCenter(bar)); // x = 200 → (200-12)/376 = 0.5
      await tester.pump();
      expect(seeks, [const Duration(minutes: 5)]);
      expect(scrubStates, isEmpty, reason: 'a tap is not a scrub');
    });

    testWidgets('drag previews the time and seeks once on release',
        (tester) async {
      await pump(tester);
      final bar = find.byType(VideoSeekBar);
      final gesture = await tester.startGesture(tester.getCenter(bar));
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.moveBy(const Offset(50, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(44, 0)); // x = 294 → 0.75
      await tester.pump();

      expect(seeks, isEmpty, reason: 'no seek while the finger is down');
      expect(find.text('07:30'), findsOneWidget, reason: 'time bubble');
      expect(scrubStates, [true]);

      await gesture.up();
      await tester.pump();
      expect(seeks, [const Duration(minutes: 7, seconds: 30)]);
      expect(scrubStates, [true, false]);
      expect(find.text('07:30'), findsNothing);
    });

    testWidgets('drag past either end clamps to the bounds', (tester) async {
      await pump(tester);
      final bar = find.byType(VideoSeekBar);
      await tester.drag(bar, const Offset(500, 0));
      await tester.pump();
      await tester.drag(bar, const Offset(-500, 0));
      await tester.pump();
      expect(seeks, [duration, Duration.zero]);
    });

    testWidgets('does nothing before the duration is known', (tester) async {
      await pump(tester, dur: Duration.zero, position: Duration.zero);
      await tester.tapAt(tester.getCenter(find.byType(VideoSeekBar)));
      await tester.pump();
      expect(seeks, isEmpty);
      expect(scrubStates, isEmpty);
    });

    testWidgets('exposes slider semantics that nudge by ten seconds',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, position: const Duration(seconds: 5));
      final seek = find.semantics.byLabel('Seek');
      final node = seek.evaluate().single;
      expect(node.value, '00:05');
      expect(node.increasedValue, '00:15');
      expect(node.decreasedValue, '00:00');
      tester.semantics.performAction(seek, SemanticsAction.increase);
      tester.semantics.performAction(seek, SemanticsAction.decrease);
      await tester.pump();
      expect(seeks, [const Duration(seconds: 15), Duration.zero]);
      handle.dispose();
    });
  });
}
