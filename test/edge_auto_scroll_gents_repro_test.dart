/// Issue #2, gents-faithful reproduction: the exact AmoebaDashboard config
/// (8x12 field, flexing 74-150px cells, gap 12, long-press activation), the
/// exact 13-tile seed layout, and the exact embedding (Expanded inside a
/// Column between a header and footer, under SafeArea) at a realistic desktop
/// window size. Drag the bottom tile to the top edge and assert the board
/// auto-scrolls up so the tile can be dropped above the fold.
@TestOn('vm')
library;

import 'package:amoeba_grid/amoeba_grid.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _AllDevices extends MaterialScrollBehavior {
  const _AllDevices();
  @override
  Set<PointerDeviceKind> get dragDevices => PointerDeviceKind.values.toSet();
}

// Verbatim from gents amoeba_dashboard.dart.
const _config = AmoebaGridConfig(
  columns: 8,
  rows: 12,
  minCellExtent: 74,
  maxCellExtent: 150,
  gap: 12,
  insideCornerRadius: 0,
  outsideCornerRadius: 0,
  bodyDragActivation: BodyDragActivation.longPress,
);

// Verbatim seed layout: id -> (col, row, width, height). 'backlog' at row 11.
const _defaultShapes = <String, (int, int, int, int)>{
  'now': (0, 0, 3, 2),
  'pulse': (3, 0, 2, 2),
  'build_map': (5, 0, 3, 2),
  'world': (0, 2, 5, 3),
  'cost_ladder': (5, 2, 3, 3),
  'activity': (0, 5, 4, 2),
  'background': (4, 5, 4, 2),
  'guardrails': (0, 7, 2, 2),
  'commits': (2, 7, 3, 2),
  'verify': (5, 7, 3, 2),
  'gates': (0, 9, 4, 2),
  'backlog': (0, 11, 4, 2),
  'history': (4, 9, 4, 3),
};

void main() {
  testWidgets('gents-faithful: drag bottom tile to top edge auto-scrolls up',
      (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1440, 900);

    final controller = AmoebaGridController(config: _config);
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      scrollBehavior: const _AllDevices(),
      home: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 64, child: ColoredBox(color: Colors.grey)),
              const SizedBox(height: 12),
              Expanded(
                child: AmoebaGridView(
                  controller: controller,
                  cards: [
                    for (final e in _defaultShapes.entries)
                      AmoebaGridCard(
                        id: e.key,
                        initialShape: CardShape.rect(
                            e.value.$1, e.value.$2, e.value.$3, e.value.$4),
                        child: ColoredBox(
                            key: ValueKey('child-${e.key}'),
                            color: const Color(0xFF3355FF)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final vertical = tester
        .stateList<ScrollableState>(
            find.byWidgetPredicate((w) => w is Scrollable))
        .map((s) => s.position)
        .firstWhere((p) => p.axis == Axis.vertical);

    // Scroll to the bottom so 'backlog' is on-screen.
    vertical.jumpTo(vertical.maxScrollExtent);
    await tester.pump();
    expect(vertical.maxScrollExtent, greaterThan(300),
        reason: 'precondition: board is taller than the viewport');
    final startPixels = vertical.pixels;

    // Long-press 'backlog', then drag to the top viewport edge and hold.
    final grab = tester.getCenter(find.byKey(const ValueKey('child-backlog')));
    final gesture = await tester.startGesture(grab);
    await tester.pump(const Duration(milliseconds: 400)); // exceed hold
    await gesture.moveTo(const Offset(300, 20)); // pin near the top edge
    await tester.pump();

    // Real users don't hold perfectly still — they push against the edge with
    // small jitter, firing a move event every frame that resets the drag
    // point and re-runs updateDrag alongside the ticker's own updateDrag.
    for (var i = 0; i < 200; i++) {
      await gesture.moveBy(Offset(i.isEven ? 0.4 : -0.4, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }

    await gesture.up();
    await tester.pumpAndSettle();

    expect(vertical.pixels, lessThan(startPixels - 200),
        reason: 'pushing against the top edge should have scrolled the board up');
    expect(controller.committedShape('backlog')!.minRow, lessThanOrEqualTo(1),
        reason: 'the tile should have followed the pointer to the top of the '
            'board across the fold');
  });
}
