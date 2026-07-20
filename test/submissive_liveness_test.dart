import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amoeba_grid/amoeba_grid.dart';
import 'package:amoeba_grid/src/engine/handles.dart';
import 'package:amoeba_grid/src/widgets/card_chrome.dart';

void main() {
  const config = AmoebaGridConfig(
      columns: 12, rows: 12, minCellExtent: 100, maxCellExtent: 100,
      gap: 12, insideCornerRadius: 10, outsideCornerRadius: 20);

  test('corner drag covering a neighbor relocates it live (controller)', () {
    final controller = AmoebaGridController(config: config)
      ..registerCards({
        'agg': CardShape.rect(1, 1, 1, 1),
        'side': CardShape.rect(3, 1, 1, 1),
      });
    final metrics = GridMetrics.resolve(config, const Size(800, 600));
    controller.updateMetrics(metrics);

    final se = handlesFor('agg', controller.committedShape('agg')!, metrics)
        .firstWhere((h) => h.corner == CornerKind.southEast && !h.concave);
    controller.startResize(se, se.center);
    controller.updateDrag(se.center + Offset(metrics.pitch * 3.1, 0));

    // Mid-drag, before any drop: side must already be relocated.
    final sub = controller.session!.submissives['side'];
    expect(sub, isNotNull, reason: 'side should be reacting live');
    expect(sub!.relocated, isTrue);
    expect(controller.effectiveShape('side'), isNot(CardShape.rect(3, 1, 1, 1)));
  });

  testWidgets('mid-drag, the submissive card surface renders its retreat',
      (tester) async {
    final controller = AmoebaGridController(config: config);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AmoebaGridView(
          controller: controller,
          cards: [
            AmoebaGridCard(
                id: 'agg',
                initialShape: CardShape.rect(1, 1, 1, 1),
                child: const SizedBox()),
            AmoebaGridCard(
                id: 'side',
                initialShape: CardShape.rect(3, 1, 1, 1),
                child: const SizedBox()),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final metrics = controller.metrics!;

    final se = handlesFor('agg', controller.committedShape('agg')!, metrics)
        .firstWhere((h) => h.corner == CornerKind.southEast && !h.concave);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.down(se.center);
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(Offset(metrics.pitch * 3.1 / 20, 0));
      await tester.pump(const Duration(milliseconds: 8));
    }

    // Mid-drag: find the AmoebaCardSurface rendering the submissive and
    // check the shape it was handed.
    final surfaces =
        tester.widgetList<AmoebaCardSurface>(find.byType(AmoebaCardSurface));
    final relocated = controller.session!.submissives['side']!.shape;
    expect(
        surfaces.any((s) => s.shape == relocated), isTrue,
        reason: 'the retreat must render live, not only on drop');

    await gesture.up();
    await tester.pumpAndSettle();
  });
}
