import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_grid/liquid_grid.dart';
import 'package:liquid_grid/src/engine/handles.dart';

void main() {
  const config = LiquidGridConfig(columns: 8, rows: 8);

  LiquidGridController makeController(LiquidGridStorage storage) {
    final controller = LiquidGridController(config: config, storage: storage)
      ..registerCards({
        'a': CardShape.rect(0, 0, 2, 2),
        'b': CardShape.rect(4, 0, 2, 2),
      });
    controller
        .updateMetrics(GridMetrics.resolve(config, const Size(1200, 800)));
    return controller;
  }

  test('move drag snaps, trims the submissive, commits, persists', () async {
    final storage = LiquidGridMemoryStorage();
    final controller = makeController(storage);
    await controller.load();
    final metrics = controller.metrics!;
    final pitch = metrics.pitch;

    // Grab card a and drag it 3 columns east, into b's west flank.
    controller.startMove('a', const Offset(100, 100));
    controller.updateDrag(Offset(100 + pitch * 3.1, 100));

    expect(controller.session!.preview, CardShape.rect(3, 0, 2, 2));
    final submissive = controller.session!.submissives['b']!;
    expect(submissive.entryEdge, CardinalEdge.west);
    expect(submissive.shape, CardShape.rect(5, 0, 1, 2),
        reason: 'b defers its west column to the aggressor');

    // Dragging fully through and past b reverts it (transient values).
    controller.updateDrag(Offset(100 + pitch * 6.1, 100));
    expect(controller.session!.submissives.containsKey('b'), isFalse);

    // Back into contact — a fresh contact, now approaching from the east.
    // The aggressor consumes b entirely from that side, so b relocates
    // west (opposite the new entry edge). Drop records both shapes.
    controller.updateDrag(Offset(100 + pitch * 3.1, 100));
    final recontact = controller.session!.submissives['b']!;
    expect(recontact.entryEdge, CardinalEdge.east);
    expect(recontact.relocated, isTrue);
    await controller.endDrag();
    expect(controller.committedShape('a'), CardShape.rect(3, 0, 2, 2));
    expect(controller.committedShape('b'), CardShape.rect(1, 0, 2, 2));

    // A fresh controller over the same storage restores the user layout.
    final revived = makeController(storage);
    await revived.load();
    expect(revived.committedShape('a'), CardShape.rect(3, 0, 2, 2));
    expect(revived.committedShape('b'), CardShape.rect(1, 0, 2, 2));
  });

  test('cancel reverts everything', () async {
    final controller = makeController(LiquidGridMemoryStorage());
    await controller.load();
    final pitch = controller.metrics!.pitch;
    controller.startMove('a', const Offset(100, 100));
    controller.updateDrag(Offset(100 + pitch * 3.1, 100));
    controller.cancelDrag();
    expect(controller.committedShape('a'), CardShape.rect(0, 0, 2, 2));
    expect(controller.effectiveShape('b'), CardShape.rect(4, 0, 2, 2));
  });

  test('1x1 submissive relocates opposite the entry edge', () async {
    final storage = LiquidGridMemoryStorage();
    final controller = LiquidGridController(config: config, storage: storage)
      ..registerCards({
        'big': CardShape.rect(0, 0, 2, 1),
        'tiny': CardShape.rect(3, 0, 1, 1),
      });
    controller
        .updateMetrics(GridMetrics.resolve(config, const Size(1200, 800)));
    await controller.load();
    final pitch = controller.metrics!.pitch;

    controller.startMove('big', const Offset(50, 50));
    controller.updateDrag(Offset(50 + pitch * 2.1, 50));

    final tiny = controller.session!.submissives['tiny']!;
    expect(tiny.relocated, isTrue);
    expect(tiny.shape, CardShape.rect(4, 0, 1, 1),
        reason: 'jumps east, opposite the west entry edge');
  });

  test('re-contact from another side computes a fresh entry edge', () async {
    final config8 = const LiquidGridConfig(columns: 8, rows: 8);
    final controller =
        LiquidGridController(config: config8, storage: LiquidGridMemoryStorage())
          ..registerCards({
            'a': CardShape.rect(6, 3, 1, 1),
            'b': CardShape.rect(3, 3, 2, 2),
          });
    controller
        .updateMetrics(GridMetrics.resolve(config8, const Size(1200, 800)));
    await controller.load();
    final pitch = controller.metrics!.pitch;

    // Start east of b and push west into its east edge.
    controller.startMove('a', const Offset(0, 0));
    controller.updateDrag(Offset(-pitch * 2.1, 0));
    expect(controller.session!.submissives['b']!.entryEdge, CardinalEdge.east);

    // Without dropping: retreat clear of b...
    controller.updateDrag(const Offset(0, 0));
    expect(controller.session!.submissives, isEmpty);

    // ...swing below b, then push up into its south edge.
    controller.updateDrag(Offset(-pitch * 3.1, pitch * 2.1));
    expect(controller.session!.submissives, isEmpty,
        reason: 'directly below b, not overlapping');
    controller.updateDrag(Offset(-pitch * 3.1, pitch * 1.1));
    expect(
        controller.session!.submissives['b']!.entryEdge, CardinalEdge.south);
  });

  test('resize preview holds origin shape until release', () async {
    final controller = makeController(LiquidGridMemoryStorage());
    await controller.load();
    final metrics = controller.metrics!;
    final pitch = metrics.pitch;

    final handles =
        handlesFor('a', controller.committedShape('a')!, metrics);
    final east = handles.firstWhere((h) =>
        !h.isCorner && h.edge == CardinalEdge.east && h.cell.row == 0);

    controller.startResize(east, const Offset(0, 0));
    controller.updateDrag(Offset(pitch * 1.2, 0));
    // Preview extends only row 0 (strip resize), original committed intact.
    expect(controller.session!.preview.contains(2, 0), isTrue);
    expect(controller.session!.preview.contains(2, 1), isFalse);
    expect(controller.committedShape('a'), CardShape.rect(0, 0, 2, 2));

    await controller.endDrag();
    expect(controller.committedShape('a')!.contains(2, 0), isTrue);
  });
}
