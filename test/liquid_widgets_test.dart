import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_grid/liquid_grid.dart';

void main() {
  const config = LiquidGridConfig(
      columns: 8, rows: 8, gap: 10, minCellExtent: 80, maxCellExtent: 80);
  final metrics = GridMetrics.resolve(config, const Size(800, 800));

  // L-shape: 1-wide arm on top, 2-wide foot on the bottom.
  final lShape = CardShape(
      const [CellIndex(0, 0), CellIndex(0, 1), CellIndex(1, 1)]);

  Widget host(CardShape shape, Widget child) {
    final geometry = LiquidCardGeometry.compute(shape, metrics);
    return MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox.fromSize(
            size: geometry.size,
            child: LiquidCardScope(geometry: geometry, child: child),
          ),
        ),
      ),
    );
  }

  testWidgets('LiquidContentArea places its child in the largest rect',
      (tester) async {
    await tester.pumpWidget(host(
      lShape,
      const LiquidContentArea(child: SizedBox.expand(key: Key('content'))),
    ));
    final size = tester.getSize(find.byKey(const Key('content')));
    // Largest rect of the L is the 2-cell strip (170 x 80) — either the
    // bottom foot or the left arm; both are 2 cells.
    expect(size.width * size.height, closeTo(170 * 80, 1));
  });

  testWidgets('LiquidRegions builds one child per rectangular region',
      (tester) async {
    final seen = <int>[];
    await tester.pumpWidget(host(
      lShape,
      LiquidRegions(
        builder: (context, region) {
          seen.add(region.index);
          return Text('r${region.index}');
        },
      ),
    ));
    expect(seen.toSet(), {0, 1});
    expect(find.text('r0'), findsOneWidget);
    expect(find.text('r1'), findsOneWidget);
  });

  testWidgets('LiquidColumn narrows children to the band at their position',
      (tester) async {
    await tester.pumpWidget(host(
      lShape,
      const LiquidColumn(
        children: [
          SizedBox(key: Key('top'), height: 40),
          SizedBox(key: Key('mid'), height: 40),
          SizedBox(key: Key('low'), height: 200),
        ],
      ),
    ));
    final top = tester.getSize(find.byKey(const Key('top')));
    final low = tester.getSize(find.byKey(const Key('low')));
    expect(top.width, closeTo(80, 0.001),
        reason: 'top band is the 1-cell arm');
    expect(low.width, closeTo(170, 0.001),
        reason: 'bottom band is the 2-cell foot');
  });

  testWidgets('LiquidText fills the arm with short lines and the foot wide',
      (tester) async {
    await tester.pumpWidget(host(
      lShape,
      const LiquidText(
        'alpha beta gamma delta epsilon zeta eta theta iota kappa lambda '
        'mu nu xi omicron pi rho sigma tau upsilon phi chi psi omega',
        style: TextStyle(fontSize: 12),
      ),
    ));
    final render = tester.renderObject<RenderBox>(find.byType(LiquidText));
    expect(render.size.width, greaterThan(0));
    // Smoke: laid out without exceptions and produced paint content.
    expect(tester.takeException(), isNull);
  });

  testWidgets('fluid widgets degrade gracefully outside a card',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: LiquidColumn(children: [Text('plain')]),
            ),
            Expanded(child: LiquidText('no scope here')),
            Expanded(
              child: LiquidContentArea(child: Text('safe')),
            ),
          ],
        ),
      ),
    ));
    expect(find.text('plain'), findsOneWidget);
    expect(find.text('safe'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('LiquidPadding republishes deflated geometry', (tester) async {
    LiquidCardGeometry? inner;
    await tester.pumpWidget(host(
      lShape,
      LiquidPadding(
        padding: const EdgeInsets.all(10),
        child: Builder(builder: (context) {
          inner = LiquidCardScope.maybeOf(context);
          return const SizedBox();
        }),
      ),
    ));
    expect(inner, isNotNull);
    expect(inner!.insets, const EdgeInsets.all(10));
    expect(inner!.size.width,
        closeTo(LiquidCardGeometry.compute(lShape, metrics).size.width - 20,
            0.001));
  });
}
