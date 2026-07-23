/// Regression: dragging a card to the top/bottom viewport edge on a layout
/// TALLER than the viewport must auto-scroll the board so the card follows the
/// pointer past the current fold. Issue #2.
///
/// The card's move preview is driven by the pointer's CONTENT-space position
/// (viewport point + scroll offset). Without auto-scroll, a card grabbed at the
/// bottom of a tall board can only travel as far up as the current view reaches
/// — a drop target above the fold is unreachable in one gesture. The edge
/// auto-scroller must pan the board while the pointer is pinned at the edge and
/// keep re-feeding the drag so the card keeps climbing.
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

const _cards = [
  (id: 'top', col: 0, row: 0, w: 4, h: 2),
  (id: 'mid', col: 0, row: 5, w: 4, h: 2),
  (id: 'bottom', col: 0, row: 11, w: 4, h: 2),
];

Future<AmoebaGridController> _pumpTallBoard(
  WidgetTester tester, {
  required BodyDragActivation activation,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(800, 600);

  final controller = AmoebaGridController(
    config: AmoebaGridConfig(
      columns: 8,
      rows: 4,
      gap: 12,
      minCellExtent: 80,
      maxCellExtent: 80,
      bodyDragActivation: activation,
    ),
  );

  await tester.pumpWidget(MaterialApp(
    scrollBehavior: const _AllDevices(),
    home: Scaffold(
      body: AmoebaGridView(
        controller: controller,
        cards: [
          for (final c in _cards)
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
  ));
  await tester.pumpAndSettle();
  return controller;
}

ScrollPosition _verticalPosition(WidgetTester tester) => tester
    .stateList<ScrollableState>(find.byWidgetPredicate((w) => w is Scrollable))
    .map((s) => s.position)
    .firstWhere((p) => p.axis == Axis.vertical);

void main() {
  // 'bottom' sits at rows 11-12 → occupiedRows == 13, a board ~2x the viewport
  // height (content ~1208px tall vs 600px viewport).

  testWidgets(
      'immediate drag to top edge auto-scrolls up and the card follows',
      (tester) async {
    addTearDown(tester.view.reset);
    final controller = await _pumpTallBoard(tester,
        activation: BodyDragActivation.immediate);
    addTearDown(controller.dispose);

    final vertical = _verticalPosition(tester);
    vertical.jumpTo(vertical.maxScrollExtent);
    await tester.pump();
    expect(vertical.pixels, greaterThan(400),
        reason: 'precondition: board is a tall, scrollable layout');

    final grab = tester.getCenter(find.byKey(const ValueKey('child-bottom')));
    final gesture = await tester.startGesture(grab);
    await tester.pump();
    await gesture.moveTo(const Offset(200, 20)); // pin near the top edge
    await tester.pump();

    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    await gesture.up();
    await tester.pumpAndSettle();

    expect(vertical.pixels, lessThan(50),
        reason: 'holding at the top edge should have scrolled the board up');
    expect(controller.committedShape('bottom')!.minRow, lessThanOrEqualTo(1),
        reason: 'the card should have followed the pointer to the top of the '
            'board, not stalled at the old viewport fold');
  });

  testWidgets(
      'immediate drag to bottom edge auto-scrolls down and the card follows',
      (tester) async {
    addTearDown(tester.view.reset);
    final controller = await _pumpTallBoard(tester,
        activation: BodyDragActivation.immediate);
    addTearDown(controller.dispose);

    final vertical = _verticalPosition(tester);
    expect(vertical.pixels, 0, reason: 'precondition: start at the top');

    // Grab 'top' (visible at the top) and drag to the bottom viewport edge.
    final grab = tester.getCenter(find.byKey(const ValueKey('child-top')));
    final gesture = await tester.startGesture(grab);
    await tester.pump();
    await gesture.moveTo(const Offset(200, 580)); // pin near the bottom edge
    await tester.pump();

    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    await gesture.up();
    await tester.pumpAndSettle();

    expect(vertical.pixels, greaterThan(vertical.maxScrollExtent - 50),
        reason: 'holding at the bottom edge should have scrolled the board '
            'down to the end');
    expect(controller.committedShape('top')!.maxRow, greaterThanOrEqualTo(11),
        reason: 'the card should have followed the pointer to the bottom of '
            'the board');
  });

  testWidgets(
      'longPress drag to top edge auto-scrolls up and the card follows',
      (tester) async {
    addTearDown(tester.view.reset);
    final controller = await _pumpTallBoard(tester,
        activation: BodyDragActivation.longPress);
    addTearDown(controller.dispose);

    final vertical = _verticalPosition(tester);
    vertical.jumpTo(vertical.maxScrollExtent);
    await tester.pump();
    expect(vertical.pixels, greaterThan(400),
        reason: 'precondition: board is a tall, scrollable layout');

    final grab = tester.getCenter(find.byKey(const ValueKey('child-bottom')));
    final gesture = await tester.startGesture(grab);
    // Hold past the long-press threshold (350ms) to start the body drag.
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.moveTo(const Offset(200, 20)); // pin near the top edge
    await tester.pump();

    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    await gesture.up();
    await tester.pumpAndSettle();

    expect(vertical.pixels, lessThan(50),
        reason: 'holding at the top edge should have scrolled the board up');
    expect(controller.committedShape('bottom')!.minRow, lessThanOrEqualTo(1),
        reason: 'the card should have followed the pointer to the top of the '
            'board, not stalled at the old viewport fold');
  });
}
