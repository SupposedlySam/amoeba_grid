import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../foundation/cell.dart';
import '../foundation/config.dart';

/// Resolved pixel geometry for one viewport size.
///
/// The grid uses square units. The config's column/row counts are minimums:
/// when the viewport fits more units at [AmoebaGridConfig.maxCellExtent],
/// the field grows to fill it. Cell extent flexes between the config's min
/// and max; when even the minimum count can't fit at [minCellExtent], the
/// content overflows and pans.
@immutable
class GridMetrics {
  const GridMetrics._({
    required this.config,
    required this.cellExtent,
    required this.viewportSize,
    required this.columns,
    required this.rows,
  });

  /// [minColumns]/[minRows] extend the field to cover occupied cells, so a
  /// card placed on a wide window can never fall outside the pannable area
  /// when the window shrinks.
  factory GridMetrics.resolve(
    AmoebaGridConfig config,
    Size viewportSize, {
    int minColumns = 0,
    int minRows = 0,
  }) {
    int unitsThatFit(double viewportExtent) =>
        ((viewportExtent - config.gap) /
                (config.maxCellExtent + config.gap))
            .floor();
    final columns = math.max(math.max(config.columns, minColumns),
        _columnsThatFill(config, viewportSize.width));
    final rows = math.max(math.max(config.rows, minRows),
        unitsThatFit(viewportSize.height));
    final available = viewportSize.width - config.gap * (columns + 1);
    final ideal = available / columns;
    final extent =
        ideal.clamp(config.minCellExtent, config.maxCellExtent).toDouble();
    return GridMetrics._(
      config: config,
      cellExtent: extent,
      viewportSize: viewportSize,
      columns: columns,
      rows: rows,
    );
  }

  /// The column count whose square cells span [width] EXACTLY: n cells plus
  /// n+1 gaps, with the extent `(width - gap) / n - gap` inside
  /// [minCellExtent, maxCellExtent].
  ///
  /// This used to be the count that fits at [maxCellExtent], rounded DOWN.
  /// That count's ideal extent is >= max, so the clamp pinned cells at max
  /// and left up to a whole pitch of the viewport empty on the right (88px at
  /// 1500px wide with max 128 / gap 12). Rounding UP instead gives the
  /// smallest count whose extent is <= max, which fills the width exactly
  /// whenever that extent is still >= min.
  ///
  /// When it is not (a narrow min..max band, where no count fits exactly)
  /// this falls back to rounding down: cells at max with some slack, rather
  /// than cells below min, which would overflow and make the field pan
  /// sideways for no reason.
  static int _columnsThatFill(AmoebaGridConfig config, double width) {
    final span = (width - config.gap) / (config.maxCellExtent + config.gap);
    final up = span.ceil();
    if (up > 0 &&
        (width - config.gap) / up - config.gap >= config.minCellExtent) {
      return up;
    }
    return span.floor();
  }

  final AmoebaGridConfig config;
  final double cellExtent;
  final Size viewportSize;

  /// Effective grid dimensions: config counts grown to fill the viewport.
  final int columns;
  final int rows;

  /// Distance from one cell origin to the next (cell + one gap).
  double get pitch => cellExtent + config.gap;

  double get gap => config.gap;

  /// Total scrollable content size, including outer padding of one gap.
  ///
  /// A width that fills the viewport is computed as `columns * pitch + gap`,
  /// which lands up to ~5e-13px PAST the viewport (measured on 1 in 13
  /// widths). The canvas turns any overflow into a scroll range, so a filled
  /// field would pan by nothing. Within 1e-6px the viewport extent is taken.
  Size get contentSize => Size(
        _snapTo(columns * pitch + gap, viewportSize.width),
        _snapTo(rows * pitch + gap, viewportSize.height),
      );

  static double _snapTo(double value, double target) =>
      (value - target).abs() < 1e-6 ? target : value;

  /// Tile = cell plus half a gap on every side. Tiles partition the content
  /// area; a card's visual region is the union of its cells' tiles deflated
  /// by gap/2, which bridges gaps inside a card and guarantees exactly one
  /// [gap] between adjacent cards.
  Offset tileOrigin(int col, int row) =>
      Offset(gap / 2 + col * pitch, gap / 2 + row * pitch);

  /// The visible (gap-inset) rect of a single cell.
  Rect cellRect(CellIndex cell) {
    final tile = tileOrigin(cell.col, cell.row);
    return Rect.fromLTWH(
      tile.dx + gap / 2,
      tile.dy + gap / 2,
      cellExtent,
      cellExtent,
    );
  }

  /// Bounding rect (gap-inset) of a whole shape.
  Rect shapeBounds(CardShape shape) {
    final tl = cellRect(CellIndex(shape.minCol, shape.minRow));
    final br = cellRect(CellIndex(shape.maxCol, shape.maxRow));
    return Rect.fromLTRB(tl.left, tl.top, br.right, br.bottom);
  }

  /// The cell under a content-space point, clamped into the grid.
  CellIndex cellAt(Offset contentPoint) {
    final col = ((contentPoint.dx - gap / 2) / pitch)
        .floor()
        .clamp(0, columns - 1);
    final row = ((contentPoint.dy - gap / 2) / pitch)
        .floor()
        .clamp(0, rows - 1);
    return CellIndex(col, row);
  }

  bool cellInBounds(CellIndex cell) =>
      cell.col >= 0 && cell.col < columns && cell.row >= 0 && cell.row < rows;

  /// Snap steps for a drag: how many whole cells a pixel delta has crossed,
  /// switching at the 50% point of each successive cell (gap midpoints
  /// included, since pitch covers cell + gap).
  int snapSteps(double pixelDelta) => (pixelDelta / pitch + 0.5).floor();

  @override
  bool operator ==(Object other) =>
      other is GridMetrics &&
      other.config == config &&
      other.cellExtent == cellExtent &&
      other.viewportSize == viewportSize &&
      other.columns == columns &&
      other.rows == rows;

  @override
  int get hashCode =>
      Object.hash(config, cellExtent, viewportSize, columns, rows);
}
