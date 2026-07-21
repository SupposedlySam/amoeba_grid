@TestOn('vm')
library;

import 'package:amoeba_grid/amoeba_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('rows re-flow: a row in a notch region is narrower than one in the full region',
      (tester) async {
    // An L-card: the TOP row has col 0 notched out (only col 1 present); rows 1..3 are full width.
    final shape = CardShape({
      CellIndex(1, 0),
      CellIndex(0, 1), CellIndex(1, 1),
      CellIndex(0, 2), CellIndex(1, 2),
      CellIndex(0, 3), CellIndex(1, 3),
    });
    final controller = AmoebaGridController(
      config: const AmoebaGridConfig(columns: 2, rows: 4, minCellExtent: 100, maxCellExtent: 100, gap: 0),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 200,
          height: 400,
          child: AmoebaGridView(
            controller: controller,
            cards: [
              AmoebaGridCard(
                id: 'list',
                initialShape: shape,
                child: AmoebaListView(
                  itemExtent: 100,
                  itemCount: 4,
                  itemBuilder: (context, i) =>
                      SizedBox.expand(key: ValueKey('row$i'), child: const ColoredBox(color: Color(0xFF3355FF))),
                ),
              ),
            ],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final notchRow = tester.getSize(find.byKey(const ValueKey('row0'))).width;  // top: only col 1
    // row1 hugs the notch edge, so edge clearance keeps it narrow too —
    // row2 is the first row clear of the edge and sweeps the full width.
    final edgeRow = tester.getSize(find.byKey(const ValueKey('row1'))).width;
    final fullRow = tester.getSize(find.byKey(const ValueKey('row2'))).width;
    expect(notchRow, lessThan(fullRow),
        reason: 'row0 sits in the notched top row (one column) so it must be narrower than row2');
    expect(edgeRow, lessThan(fullRow),
        reason: 'the row flush against the notch edge keeps clearance by adopting the notch span');
    expect(fullRow, greaterThan(notchRow * 1.5),
        reason: 'the full-width row spans both columns');
  });

  testWidgets(
      'a row overlapping a notch edge adopts the narrower span (clearance)',
      (tester) async {
    // Same L-card, but rows deliberately misaligned with the 100px cell
    // rows: row1 (80..160) straddles the notch edge at y=100 and must
    // narrow; row2 (160..240 +clearance) is clear of it and stays wide.
    final shape = CardShape({
      CellIndex(1, 0),
      CellIndex(0, 1), CellIndex(1, 1),
      CellIndex(0, 2), CellIndex(1, 2),
      CellIndex(0, 3), CellIndex(1, 3),
    });
    final controller = AmoebaGridController(
      config: const AmoebaGridConfig(
          columns: 2, rows: 4, minCellExtent: 100, maxCellExtent: 100, gap: 0),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 200,
          height: 400,
          child: AmoebaGridView(
            controller: controller,
            cards: [
              AmoebaGridCard(
                id: 'list',
                initialShape: shape,
                child: AmoebaListView(
                  itemExtent: 80,
                  itemCount: 5,
                  itemBuilder: (context, i) => SizedBox.expand(
                      key: ValueKey('mis$i'),
                      child: const ColoredBox(color: Color(0xFF3355FF))),
                ),
              ),
            ],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final straddling = tester.getSize(find.byKey(const ValueKey('mis1'))).width;
    final clear = tester.getSize(find.byKey(const ValueKey('mis2'))).width;
    expect(straddling, lessThan(clear),
        reason: 'a row crossing the notch edge must narrow to the notch span '
            'instead of rendering flush against the horizontal edge');
  });

  testWidgets('outside a fluid card it degrades to a plain fixed-extent list', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 200,
          height: 250,
          child: AmoebaListView(
            itemExtent: 40,
            itemCount: 20,
            itemBuilder: (context, i) => Text('item $i'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('item 0'), findsOneWidget);
    // A full-width row when there's no shape to constrain it.
    expect(tester.getSize(find.text('item 0').first).width, greaterThan(0));
  });
}