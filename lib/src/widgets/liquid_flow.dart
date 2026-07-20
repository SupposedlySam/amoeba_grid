import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../engine/content_geometry.dart';
import 'liquid_card_scope.dart';

/// Cross-axis placement of each child within its band span.
enum LiquidFlowAlignment { start, center, end, stretch }

/// Flows children along one axis through the card's shape: at every step the
/// child is constrained to the free span at the current position, so content
/// narrows around notches and widens where the card does. Children that
/// straddle a band boundary are constrained to the intersection of the
/// spans they cross.
///
/// Outside a fluid card this behaves like a plain top-to-bottom (or
/// left-to-right) list.
class LiquidFlow extends MultiChildRenderObjectWidget {
  const LiquidFlow({
    super.key,
    this.axis = Axis.vertical,
    this.spacing = 0,
    this.alignment = LiquidFlowAlignment.stretch,
    super.children,
  });

  final Axis axis;
  final double spacing;
  final LiquidFlowAlignment alignment;

  @override
  RenderLiquidFlow createRenderObject(BuildContext context) => RenderLiquidFlow(
        geometry: LiquidCardScope.maybeOf(context),
        axis: axis,
        spacing: spacing,
        alignment: alignment,
      );

  @override
  void updateRenderObject(BuildContext context, RenderLiquidFlow renderObject) {
    renderObject
      ..geometry = LiquidCardScope.maybeOf(context)
      ..axis = axis
      ..spacing = spacing
      ..alignment = alignment;
  }
}

/// Vertical [LiquidFlow].
class LiquidColumn extends LiquidFlow {
  const LiquidColumn({
    super.key,
    super.spacing,
    super.alignment,
    super.children,
  }) : super(axis: Axis.vertical);
}

/// Horizontal [LiquidFlow].
class LiquidRow extends LiquidFlow {
  const LiquidRow({
    super.key,
    super.spacing,
    super.alignment,
    super.children,
  }) : super(axis: Axis.horizontal);
}

class LiquidFlowParentData extends ContainerBoxParentData<RenderBox> {}

class RenderLiquidFlow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, LiquidFlowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, LiquidFlowParentData> {
  RenderLiquidFlow({
    required this._geometry,
    required this._axis,
    required this._spacing,
    required this._alignment,
  });

  LiquidCardGeometry? _geometry;
  set geometry(LiquidCardGeometry? value) {
    if (value == _geometry) return;
    _geometry = value;
    markNeedsLayout();
  }

  Axis _axis;
  set axis(Axis value) {
    if (value == _axis) return;
    _axis = value;
    markNeedsLayout();
  }

  double _spacing;
  set spacing(double value) {
    if (value == _spacing) return;
    _spacing = value;
    markNeedsLayout();
  }

  LiquidFlowAlignment _alignment;
  set alignment(LiquidFlowAlignment value) {
    if (value == _alignment) return;
    _alignment = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! LiquidFlowParentData) {
      child.parentData = LiquidFlowParentData();
    }
  }

  @override
  void performLayout() {
    final vertical = _axis == Axis.vertical;
    size = constraints.biggest;
    final bands = _bands();

    var cursor = bands.isEmpty ? 0.0 : bands.first.start;
    var child = firstChild;
    while (child != null) {
      final parentData = child.parentData! as LiquidFlowParentData;
      final band = _bandAt(bands, cursor);
      if (band == null) {
        // Out of shape: stack remaining children below/right; the card clip
        // hides them, matching how a rectangular overflow behaves.
        child.layout(
            vertical
                ? BoxConstraints(maxWidth: size.width)
                : BoxConstraints(maxHeight: size.height),
            parentUsesSize: true);
        parentData.offset =
            vertical ? Offset(0, cursor) : Offset(cursor, 0);
        cursor += (vertical ? child.size.height : child.size.width) +
            _spacing;
        child = parentData.nextSibling;
        continue;
      }
      cursor = cursor < band.start ? band.start : cursor;

      var span = _widestSpan(band, vertical);
      child.layout(_spanConstraints(span, vertical), parentUsesSize: true);
      var extent = vertical ? child.size.height : child.size.width;

      // Straddling a band boundary: constrain to the intersection of the
      // spans this child crosses, then re-layout once.
      final crossed = _intersectAcross(bands, cursor, cursor + extent, span,
          vertical);
      if (crossed != null && crossed != span) {
        span = crossed;
        child.layout(_spanConstraints(span, vertical),
            parentUsesSize: true);
        extent = vertical ? child.size.height : child.size.width;
      }

      final free = (vertical ? span.width : span.height) -
          (vertical ? child.size.width : child.size.height);
      final alignShift = switch (_alignment) {
        LiquidFlowAlignment.start || LiquidFlowAlignment.stretch => 0.0,
        LiquidFlowAlignment.center => free / 2,
        LiquidFlowAlignment.end => free,
      };
      parentData.offset = vertical
          ? Offset(span.left + alignShift, cursor)
          : Offset(cursor, span.top + alignShift);
      cursor += extent + _spacing;
      child = parentData.nextSibling;
    }
  }

  BoxConstraints _spanConstraints(Rect span, bool vertical) {
    final cross = vertical ? span.width : span.height;
    final min = _alignment == LiquidFlowAlignment.stretch ? cross : 0.0;
    return vertical
        ? BoxConstraints(minWidth: min, maxWidth: cross)
        : BoxConstraints(minHeight: min, maxHeight: cross);
  }

  List<LiquidBand> _bands() {
    final geometry = _geometry;
    if (geometry == null) {
      final vertical = _axis == Axis.vertical;
      final extent = vertical ? size.height : size.width;
      return [
        LiquidBand(
            start: 0, end: extent, spans: [Offset.zero & size]),
      ];
    }
    return _axis == Axis.vertical
        ? geometry.rowBands
        : geometry.columnBands;
  }

  LiquidBand? _bandAt(List<LiquidBand> bands, double position) {
    for (final band in bands) {
      if (position < band.end) return band;
    }
    return null;
  }

  Rect _widestSpan(LiquidBand band, bool vertical) {
    var best = band.spans.first;
    for (final span in band.spans) {
      final size = vertical ? span.width : span.height;
      final bestSize = vertical ? best.width : best.height;
      if (size > bestSize) best = span;
    }
    return best;
  }

  /// Intersection of [span] with the matching span of every band the range
  /// [from, to) crosses. Returns null when the child stays inside one band.
  Rect? _intersectAcross(List<LiquidBand> bands, double from, double to,
      Rect span, bool vertical) {
    var result = span;
    var crossed = false;
    for (final band in bands) {
      if (band.end <= from || band.start >= to) continue;
      if (from >= band.start && to <= band.end) continue;
      crossed = true;
      // Pick the band span with the largest cross-axis overlap.
      Rect? best;
      var bestOverlap = 0.0;
      for (final candidate in band.spans) {
        final overlap = vertical
            ? (candidate.right.clamp(span.left, span.right) -
                candidate.left.clamp(span.left, span.right))
            : (candidate.bottom.clamp(span.top, span.bottom) -
                candidate.top.clamp(span.top, span.bottom));
        if (overlap > bestOverlap) {
          bestOverlap = overlap;
          best = candidate;
        }
      }
      if (best == null) return result; // no usable span; keep what we have
      result = vertical
          ? Rect.fromLTRB(
              best.left > result.left ? best.left : result.left,
              result.top,
              best.right < result.right ? best.right : result.right,
              result.bottom)
          : Rect.fromLTRB(
              result.left,
              best.top > result.top ? best.top : result.top,
              result.right,
              best.bottom < result.bottom ? best.bottom : result.bottom);
      if ((vertical ? result.width : result.height) <= 0) return span;
    }
    return crossed ? result : null;
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
