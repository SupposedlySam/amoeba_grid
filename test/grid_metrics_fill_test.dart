import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:amoeba_grid/amoeba_grid.dart';

/// Whether SOME column count n >= [minColumns] lays square cells across
/// [width] exactly (n cells + n+1 gaps) with the cell extent inside
/// [minCellExtent, maxCellExtent]. When one exists, the grid has no excuse
/// for leaving a strip of the viewport empty.
bool exactlyFillable(AmoebaGridConfig c, double width, int minColumns) {
  for (var n = minColumns; n <= 1000; n++) {
    final extent = (width - c.gap) / n - c.gap;
    if (extent < c.minCellExtent) return false;
    if (extent <= c.maxCellExtent) return true;
  }
  return false;
}

void main() {
  const configs = [
    // The README / gents shape.
    AmoebaGridConfig(
      columns: 8,
      rows: 12,
      minCellExtent: 68,
      maxCellExtent: 128,
    ),
    AmoebaGridConfig(
      columns: 8,
      rows: 12,
      minCellExtent: 74,
      maxCellExtent: 150,
    ),
    // Defaults.
    AmoebaGridConfig(),
    // A narrow band, where some widths genuinely cannot be filled.
    AmoebaGridConfig(
      columns: 4,
      rows: 4,
      minCellExtent: 100,
      maxCellExtent: 110,
      gap: 8,
    ),
  ];

  test('fills the full viewport width whenever square cells can', () {
    var fillable = 0;
    var previouslySlack = 0;
    for (final c in configs) {
      for (var w = 200.0; w <= 3200; w += 7) {
        final m = GridMetrics.resolve(c, Size(w, 900));
        expect(
          m.cellExtent,
          inInclusiveRange(c.minCellExtent, c.maxCellExtent),
        );
        if (!exactlyFillable(c, w, c.columns)) continue;
        fillable++;
        // Positive control: the old rule (count what fits at max, clamp)
        // left this many pixels unused. Counting them proves the sweep
        // reaches the case the bug lives in.
        final oldCols = ((w - c.gap) / (c.maxCellExtent + c.gap)).floor();
        if (oldCols > c.columns) previouslySlack++;
        expect(
          m.contentSize.width,
          // Exactly, not closeTo: a float overshoot of 1e-13 still becomes a
          // horizontal scroll range in the canvas.
          equals(w),
          reason:
              'width $w with $c: ${m.columns} cols of '
              '${m.cellExtent.toStringAsFixed(2)}px leave '
              '${(w - m.contentSize.width).toStringAsFixed(2)}px unused',
        );
      }
    }
    expect(fillable, greaterThan(500));
    expect(previouslySlack, greaterThan(100));
  });

  test(
    'an unfillable width still never overflows or leaves a cell of slack',
    () {
      const c = AmoebaGridConfig(
        columns: 1,
        rows: 4,
        minCellExtent: 100,
        maxCellExtent: 110,
        gap: 8,
      );
      var unfillable = 0;
      for (var w = 200.0; w <= 3200; w += 7) {
        if (exactlyFillable(c, w, c.columns)) continue;
        unfillable++;
        final m = GridMetrics.resolve(c, Size(w, 900));
        expect(
          m.contentSize.width,
          lessThanOrEqualTo(w + 1e-6),
          reason: 'must not pan horizontally when it does not have to',
        );
        expect(
          w - m.contentSize.width,
          lessThan(m.pitch),
          reason: 'slack of a whole pitch means a column was left out',
        );
      }
      expect(unfillable, greaterThan(10));
    },
  );

  test('config minimum columns still win over filling', () {
    const c = AmoebaGridConfig(
      columns: 8,
      rows: 12,
      minCellExtent: 68,
      maxCellExtent: 128,
    );
    final m = GridMetrics.resolve(c, const Size(400, 900));
    expect(m.columns, 8);
    expect(m.cellExtent, 68);
    expect(m.contentSize.width, greaterThan(400), reason: 'too narrow: pans');
  });
}
