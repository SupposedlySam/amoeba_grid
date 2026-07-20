import 'package:flutter/widgets.dart';

import '../engine/content_geometry.dart';

/// Publishes a card's shape-aware [FluidCardGeometry] to its content.
///
/// `FluidGridView` injects one around every card's child automatically, so
/// any descendant — at any depth — can adapt to the polyomino via
/// [FluidCardScope.maybeOf]. The Fluid* content widgets (FluidContentArea,
/// FluidRegions, FluidColumn/FluidRow, FluidText) all read it; outside a
/// fluid card they degrade gracefully to plain rectangular behavior.
class FluidCardScope extends InheritedWidget {
  const FluidCardScope({
    super.key,
    required this.geometry,
    required super.child,
  });

  final FluidCardGeometry geometry;

  static FluidCardGeometry? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<FluidCardScope>()
      ?.geometry;

  static FluidCardGeometry of(BuildContext context) {
    final geometry = maybeOf(context);
    assert(geometry != null,
        'FluidCardScope.of called outside a fluid card subtree');
    return geometry!;
  }

  @override
  bool updateShouldNotify(FluidCardScope oldWidget) =>
      oldWidget.geometry != geometry;
}

/// Shape-aware [Padding]: pads the child AND republishes the geometry with
/// the padding carved off, so fluid widgets below it keep seeing spans and
/// regions in their own coordinates. Use this instead of a plain Padding
/// between the card and any Fluid* layout widget.
class FluidPadding extends StatelessWidget {
  const FluidPadding({super.key, required this.padding, required this.child});

  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final geometry = FluidCardScope.maybeOf(context);
    final padded = Padding(padding: padding, child: child);
    if (geometry == null) return padded;
    return Padding(
      padding: padding,
      child: FluidCardScope(
        geometry: geometry.deflate(padding),
        child: child,
      ),
    );
  }
}

/// Lays its child in the **largest rectangle fully inside the card shape**
/// — a SafeArea for notches. The child stays rectangular but is never bitten
/// by a concave cutout, no matter how the user reshapes the card.
class FluidContentArea extends StatelessWidget {
  const FluidContentArea({
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
    final geometry = FluidCardScope.maybeOf(context);
    if (geometry == null) {
      return Padding(padding: padding, child: child);
    }
    final rect = padding.deflateRect(geometry.largestRect);
    if (rect.isEmpty) return const SizedBox.shrink();
    Widget content = FluidCardScope(
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
class FluidRegions extends StatelessWidget {
  const FluidRegions({super.key, required this.builder});

  final Widget? Function(BuildContext context, FluidRegion region) builder;

  @override
  Widget build(BuildContext context) {
    final geometry = FluidCardScope.maybeOf(context);
    if (geometry == null) {
      // Outside a fluid card the whole box is one region.
      return LayoutBuilder(builder: (context, constraints) {
        final region = FluidRegion(
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
                child: FluidCardScope(
                  geometry: geometry.cropTo(region.rect),
                  child: child,
                ),
              ),
        ],
      ),
    );
  }
}
