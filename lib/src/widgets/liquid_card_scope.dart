import 'package:flutter/widgets.dart';

import '../engine/content_geometry.dart';

/// Publishes a card's shape-aware [LiquidCardGeometry] to its content.
///
/// `LiquidGridView` injects one around every card's child automatically, so
/// any descendant — at any depth — can adapt to the polyomino via
/// [LiquidCardScope.maybeOf]. The Liquid* content widgets (LiquidContentArea,
/// LiquidRegions, LiquidColumn/LiquidRow, LiquidText) all read it; outside a
/// fluid card they degrade gracefully to plain rectangular behavior.
class LiquidCardScope extends InheritedWidget {
  const LiquidCardScope({
    super.key,
    required this.geometry,
    required super.child,
  });

  final LiquidCardGeometry geometry;

  static LiquidCardGeometry? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<LiquidCardScope>()
      ?.geometry;

  static LiquidCardGeometry of(BuildContext context) {
    final geometry = maybeOf(context);
    assert(geometry != null,
        'LiquidCardScope.of called outside a fluid card subtree');
    return geometry!;
  }

  @override
  bool updateShouldNotify(LiquidCardScope oldWidget) =>
      oldWidget.geometry != geometry;
}

/// Shape-aware [Padding]: pads the child AND republishes the geometry with
/// the padding carved off, so fluid widgets below it keep seeing spans and
/// regions in their own coordinates. Use this instead of a plain Padding
/// between the card and any Liquid* layout widget.
class LiquidPadding extends StatelessWidget {
  const LiquidPadding({super.key, required this.padding, required this.child});

  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final geometry = LiquidCardScope.maybeOf(context);
    final padded = Padding(padding: padding, child: child);
    if (geometry == null) return padded;
    return Padding(
      padding: padding,
      child: LiquidCardScope(
        geometry: geometry.deflate(padding),
        child: child,
      ),
    );
  }
}

/// Lays its child in the **largest rectangle fully inside the card shape**
/// — a SafeArea for notches. The child stays rectangular but is never bitten
/// by a concave cutout, no matter how the user reshapes the card.
class LiquidContentArea extends StatelessWidget {
  const LiquidContentArea({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.alignment,
  });

  final Widget child;

  /// Extra padding inside the safe rectangle.
  final EdgeInsets padding;

  /// When non-null, the child is aligned loosely inside the safe rect
  /// instead of filling it.
  final AlignmentGeometry? alignment;

  @override
  Widget build(BuildContext context) {
    final geometry = LiquidCardScope.maybeOf(context);
    if (geometry == null) {
      return Padding(padding: padding, child: child);
    }
    final rect = padding.deflateRect(geometry.largestRect);
    if (rect.isEmpty) return const SizedBox.shrink();
    Widget content = LiquidCardScope(
      geometry: geometry.cropTo(rect),
      child: child,
    );
    if (alignment != null) {
      content = Align(alignment: alignment!, child: content);
    }
    return SizedBox.expand(
      child: Stack(
        clipBehavior: Clip.none,
        children: [Positioned.fromRect(rect: rect, child: content)],
      ),
    );
  }
}

/// Explicit placement into the card's maximal-rectangle decomposition:
/// [builder] is invoked once per rectangular sub-region (area-descending —
/// region 0 is the biggest) and may return null to leave a region empty.
/// Reshaping the card changes the region set live.
class LiquidRegions extends StatelessWidget {
  const LiquidRegions({super.key, required this.builder});

  final Widget? Function(BuildContext context, LiquidRegion region) builder;

  @override
  Widget build(BuildContext context) {
    final geometry = LiquidCardScope.maybeOf(context);
    if (geometry == null) {
      // Outside a fluid card the whole box is one region.
      return LayoutBuilder(builder: (context, constraints) {
        final region = LiquidRegion(
          index: 0,
          rect: Offset.zero & constraints.biggest,
          cellWidth: 1,
          cellHeight: 1,
        );
        return builder(context, region) ?? const SizedBox.shrink();
      });
    }
    return SizedBox.expand(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final region in geometry.regions)
            if (builder(context, region) case final child?)
              Positioned.fromRect(
                rect: region.rect,
                child: LiquidCardScope(
                  geometry: geometry.cropTo(region.rect),
                  child: child,
                ),
              ),
        ],
      ),
    );
  }
}
