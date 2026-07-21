/// Regression: pressing a card must grab THAT card, even after the grid's cell extent RE-RESOLVES
/// (a window resize or a layout rearrange) following the first build.
///
/// The bug: `RawGestureDetector` constructs its recognizer exactly once, so a `GridMetrics` closed
/// over in the recognizer's constructor (the pointer-down hit test) froze at first-build values while
/// paint kept using fresh metrics. After any re-resolve the two used different cell sizes and a press
/// grabbed a card offset from the one under the pointer. The fix reads the controller's live metrics
/// at hit time. This test forces a re-resolve (resize after build), scrolls, then presses a card's
/// PAINTED centre (read from its child widget) and asserts the hit names the same card.
@TestOn('vm')
library;

import 'package:amoeba_grid/amoeba_grid.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('press hits the painted card after a post-build re-resolve + scroll', (tester) async {
    AmoebaGridDiagnostics.enabled = true;
    final downs = <Map<String, Object?>>[];
    final sub = AmoebaGridDiagnostics.events.listen((e) {
      if (e.kind == AmoebaGridEventKind.pointerDown) downs.add(e.data);
    });
    addTearDown(sub.cancel);
    addTearDown(() => AmoebaGridDiagnostics.enabled = false);
    addTearDown(tester.view.reset);

    final controller = AmoebaGridController(
      config: const AmoebaGridConfig(
        columns: 8,
        rows: 12,
        minCellExtent: 74,
        maxCellExtent: 150,
        gap: 12,
      ),
    );
    addTearDown(controller.dispose);

    const cards = [
      (id: 'a', col: 0, row: 0, w: 4, h: 2),
      (id: 'b', col: 4, row: 0, w: 4, h: 2),
      (id: 'c', col: 0, row: 2, w: 8, h: 3),
      (id: 'd', col: 0, row: 5, w: 4, h: 2),
      (id: 'e', col: 4, row: 5, w: 4, h: 2),
      (id: 'target', col: 0, row: 7, w: 4, h: 2),
      (id: 'g', col: 4, row: 7, w: 4, h: 2),
      (id: 'h', col: 0, row: 9, w: 8, h: 3),
    ];

    Widget build() => MaterialApp(
          home: Scaffold(
            body: AmoebaGridView(
              controller: controller,
              cards: [
                for (final c in cards)
                  AmoebaGridCard(
                    id: c.id,
                    initialShape: CardShape.rect(c.col, c.row, c.w, c.h),
                    child: ColoredBox(
                        key: ValueKey('child-${c.id}'),
                        color: const Color(0xFF3355FF)),
                  ),
              ],
            ),
          ),
        );

    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(820, 620);
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();

    // The trigger: re-resolve the cell extent AFTER the first build.
    tester.view.physicalSize = const Size(1000, 760);
    await tester.pumpAndSettle();

    // Scroll so 'target' sits well inside the viewport.
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(const Offset(500, 300)));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 300)));
    await tester.pumpAndSettle();

    final painted = tester.getCenter(find.byKey(const ValueKey('child-target')));
    downs.clear();
    final gesture = await tester.startGesture(painted);
    await tester.pump();
    await gesture.up();

    expect(downs, isNotEmpty, reason: 'a pointerDown diagnostic must fire on a card press');
    expect(downs.first['hit'], contains('target'),
        reason: 'pressed the painted centre of "target" at $painted; hit ${downs.first['hit']} — a '
            'different card means the pointer-down hit test used stale (pre-resize) cell metrics');
  });
}
