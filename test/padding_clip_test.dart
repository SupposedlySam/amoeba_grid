import 'package:amoeba_grid/amoeba_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const config = AmoebaGridConfig(
      columns: 5, rows: 2, minCellExtent: 100, maxCellExtent: 100,
      gap: 12, insideCornerRadius: 10, outsideCornerRadius: 22);

  testWidgets('the AmoebaPadding clip hugs the eroded silhouette in child '
      'coordinates', (tester) async {
    // L-shape: wide top, bottom-right cell missing → one interior step.
    final shape = CardShape(const [
      CellIndex(0, 0), CellIndex(1, 0), CellIndex(2, 0), CellIndex(3, 0),
      CellIndex(0, 1), CellIndex(1, 1),
    ]);
    final controller = AmoebaGridController(config: config);
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 5 * 112.0 + 12,
          height: 2 * 112.0 + 12,
          child: AmoebaGridView(
            controller: controller,
            cards: [
              AmoebaGridCard(
                id: 'l',
                initialShape: shape,
                child: AmoebaPadding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox.expand(
                      key: const ValueKey('body'),
                      child: Builder(builder: (context) {
                        return const ColoredBox(color: Color(0xFF3355FF));
                      })),
                ),
              ),
            ],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final clipFinder = find.ancestor(
        of: find.byKey(const ValueKey('body')),
        matching: find.byType(ClipPath));
    expect(clipFinder, findsWidgets);
    final clipWidget = tester.widget<ClipPath>(clipFinder.first);
    final bodySize = tester.getSize(find.byKey(const ValueKey('body')));
    final clip = clipWidget.clipper!.getClip(bodySize);

    // Deep interior: safely inside the clip.
    expect(clip.contains(Offset(bodySize.width / 4, bodySize.height / 4)),
        isTrue, reason: 'deep interior must be paintable');

    // 4px inside the child's left edge = inside the padding band that hugs
    // the outer outline (12px erosion − 12px box inset = the band ends at
    // the box edge... probe just outside the eroded outline instead): the
    // child origin sits `padding` inside the outline, so child x = -? is
    // outside — probe the INTERIOR STEP edge: the bottom region's right
    // outline runs vertically where the bottom-right cell is missing.
    // In card coords that edge is at x = 2*112 - 6 (tile edge - gap/2).
    // Child coords = card - (padding.left, padding.top).
    final stepEdgeChildX = (2 * 112.0 - 6) - 12;
    final lowRegionY = 1.5 * 112.0 - 12;
    expect(clip.contains(Offset(stepEdgeChildX - 4, lowRegionY)), isFalse,
        reason: 'within 12px of the interior step edge is padding band — '
            'must be clipped');
    expect(clip.contains(Offset(stepEdgeChildX - 20, lowRegionY)), isTrue,
        reason: 'past the padding band the interior is paintable');
  });
}
