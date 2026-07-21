import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../engine/content_geometry.dart';
import '../foundation/diagnostics.dart';
import 'amoeba_card_scope.dart';

/// Clips to the ERODED outline (the silhouette shrunk by the shape-
/// following padding band) intersected with the body box — the hard
/// guarantee that no body content paints outside the silhouette or into
/// the padding band that hugs it, whatever a child does. Interior band
/// boundaries are untouched: padding follows the edge only, exactly like
/// rectangle padding follows a rectangle.
class _OutlineClipper extends CustomClipper<Path> {
  const _OutlineClipper(this.path);

  final Path path;

  @override
  Path getClip(Size size) => Path.combine(
      PathOperation.intersect, path, Path()..addRect(Offset.zero & size));

  @override
  bool shouldReclip(_OutlineClipper oldClipper) => oldClipper.path != path;
}

/// Shape-aware card scaffold: a [header] pinned inside the shape's TOPMOST
/// solid span — where a title visually belongs, never inside a notch — and
/// a [body] that receives the FULL remaining shape below it, so shape-aware
/// children ([AmoebaListView], [AmoebaText], [AmoebaColumn]) flow into
/// every notch while the header stays put.
///
/// This widget exists because the obvious compositions both get it wrong:
/// - nesting the body in [AmoebaContentArea] windows the geometry to the
///   largest notch-free rectangle, so nothing inside ever sees a notch and
///   rows stop re-flowing;
/// - measuring "below the header" from `largestRect.top` misplaces the body
///   whenever the largest rectangle isn't the region under the title (a
///   tall silhouette with a big lower block leaves its middle empty).
///
/// The scope published to [body] is already cropped below the header, so a
/// plain (non-amoeba) child that must not be bitten by notches can simply
/// be wrapped in [AmoebaContentArea] inside the body — it then picks the
/// largest safe rectangle of the *remaining* shape.
///
/// Outside a fluid card it degrades to a plain padded header/body column.
class AmoebaShell extends StatelessWidget {
  const AmoebaShell({
    super.key,
    required this.header,
    required this.body,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 12),
    this.headerExtent = 22,
    this.gap = 8,
    this.compactExtent = 84,
    this.minHeaderWidth = 140,
  });

  final Widget header;
  final Widget body;

  /// Chrome insets between the outline and content, applied outline-aware
  /// to the body (notch interior edges included).
  final EdgeInsets padding;

  /// The header strip's fixed height.
  final double headerExtent;

  /// Vertical gap between the header strip and the body.
  final double gap;

  /// Below this shape height only the header renders — a squeezed card
  /// reads as a labeled sliver instead of clipping its content.
  final double compactExtent;

  /// A top span narrower than this can't fit a real header (fixed icons
  /// squeeze the title to nothing) — the header drops to the first band
  /// with room, or the widest span anywhere as a last resort.
  final double minHeaderWidth;

  @override
  Widget build(BuildContext context) {
    final geometry = AmoebaCardScope.maybeOf(context);
    if (geometry == null || geometry.rowBands.isEmpty) {
      return Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: headerExtent, child: header),
            SizedBox(height: gap),
            Expanded(child: ClipRect(child: body)),
          ],
        ),
      );
    }

    // The highest band whose widest span can actually FIT a header is the
    // shape's natural title position — a one-cell top arm would squeeze
    // the title to nothing between the header's fixed-width icons.
    var topBand = geometry.rowBands.first;
    var headerSpan = topBand.spans.first;
    var found = false;
    for (final band in geometry.rowBands) {
      var widest = band.spans.first;
      for (final span in band.spans) {
        if (span.width > widest.width) widest = span;
      }
      if (!found && widest.width - padding.horizontal >= minHeaderWidth) {
        topBand = band;
        headerSpan = widest;
        found = true;
      }
      // Last-resort fallback: the widest span anywhere.
      if (!found && widest.width > headerSpan.width) {
        topBand = band;
        headerSpan = widest;
      }
    }
    final headerRect = Rect.fromLTWH(
      headerSpan.left + padding.left,
      topBand.start + padding.top,
      (headerSpan.width - padding.horizontal).clamp(0.0, double.infinity),
      headerExtent,
    );

    final compact = geometry.size.height < compactExtent;
    final bodyTop = headerRect.bottom + gap;
    final positionedHeader = Positioned.fromRect(
      rect: headerRect,
      child: Align(alignment: AlignmentDirectional.centerStart, child: header),
    );
    if (compact || bodyTop >= geometry.size.height) {
      return Stack(clipBehavior: Clip.none, children: [positionedHeader]);
    }

    // Window (not outline-inset) crop below the header keeps the notch
    // structure of the remaining shape intact; the outline-aware chrome
    // padding is then AmoebaPadding's job.
    final bodyGeometry = geometry.cropTo(Rect.fromLTWH(
        0, bodyTop, geometry.size.width, geometry.size.height - bodyTop));
    return Stack(
      clipBehavior: Clip.none,
      children: [
        positionedHeader,
        Positioned.fill(
          top: bodyTop,
          child: AmoebaCardScope(
            geometry: bodyGeometry,
            child: AmoebaPadding(
              padding: EdgeInsets.fromLTRB(
                  padding.left, 0, padding.right, padding.bottom),
              // Clip to the OUTLINE, not the bounding box: the box covers
              // the whole bounding rect, including regions the polyomino
              // doesn't occupy — a child that ignores (or falls off) the
              // spans must never paint onto the page background there.
              // The padded child's local origin sits at (padding.left, 0)
              // of the body geometry, so shift the path to match.
              child: Builder(builder: (context) {
                final scoped = AmoebaCardScope.of(context);
                // Erode by the smallest chrome inset: the per-side span
                // deflation already enforces the larger sides; the clip is
                // the uniform shape-following backstop.
                final inset = [
                  padding.left, padding.right, padding.bottom,
                ].reduce((a, b) => a < b ? a : b);
                final eroded = scoped.erodedPath(inset);
                final clipped = ClipPath(
                  clipper: _OutlineClipper(eroded),
                  child: body,
                );
                if (!kDebugMode || !AmoebaGridDiagnostics.showPaddingOverlay) {
                  return clipped;
                }
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    clipped,
                    IgnorePointer(
                      child: CustomPaint(
                          painter: _PaddingOverlayPainter(scoped, eroded)),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}


/// Debug-only: the padding band in translucent red — the ring between the
/// outline and its eroded copy, hugging the silhouette like rectangle
/// padding hugs a rectangle. Letters overlapping red are violating the
/// shape-following padding.
class _PaddingOverlayPainter extends CustomPainter {
  const _PaddingOverlayPainter(this.geometry, this.eroded);

  final AmoebaCardGeometry geometry;
  final Path eroded;

  @override
  void paint(Canvas canvas, Size size) {
    final band =
        Path.combine(PathOperation.difference, geometry.path, eroded);
    canvas.clipRect(Offset.zero & size);
    canvas.drawPath(band, Paint()..color = const Color(0x55FF3B30));
  }

  @override
  bool shouldRepaint(_PaddingOverlayPainter oldDelegate) =>
      oldDelegate.geometry != geometry || oldDelegate.eroded != eroded;
}
