import 'package:flutter/widgets.dart';

import '../engine/content_geometry.dart';

/// Clips to [path] intersected with the widget's own box — the hard
/// guarantee that content paints neither outside the (eroded) silhouette
/// nor beyond the padded box.
class OutlineClipper extends CustomClipper<Path> {
  const OutlineClipper(this.path);

  final Path path;

  @override
  Path getClip(Size size) => Path.combine(
      PathOperation.intersect, path, Path()..addRect(Offset.zero & size));

  @override
  bool shouldReclip(OutlineClipper oldClipper) => oldClipper.path != path;
}

/// Debug-only: the shape-following padding band in translucent red — the
/// ring between the outline and its eroded copy. Letters overlapping red
/// are violating the padding.
class PaddingOverlayPainter extends CustomPainter {
  const PaddingOverlayPainter(this.geometry, this.eroded);

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
  bool shouldRepaint(PaddingOverlayPainter oldDelegate) =>
      oldDelegate.geometry != geometry || oldDelegate.eroded != eroded;
}
