import 'dart:async';

import 'package:flutter/foundation.dart';

/// Categories of instrumentation events emitted by the grid.
enum AmoebaGridEventKind {
  metricsResolved,
  handleHoverEnter,
  handleHoverExit,
  pointerDown,
  gestureAccepted,
  gestureRejected,
  dragStart,
  dragUpdate,
  previewChanged,
  submissiveTrimmed,
  submissiveRelocated,
  submissiveReverted,
  dragCancelled,
  layoutCommitted,
  layoutLoaded,
  layoutSaved,
  edgeAutoScroll,
}

/// One structured instrumentation event.
@immutable
class AmoebaGridEvent {
  const AmoebaGridEvent(this.kind, this.message, {this.data = const {}});

  final AmoebaGridEventKind kind;
  final String message;
  final Map<String, Object?> data;

  @override
  String toString() =>
      '[$kind] $message${data.isEmpty ? '' : ' $data'}';
}

/// Debug-only instrumentation for every detail of what the grid is doing.
///
/// Events only flow when [enabled] is true AND the app is running in debug
/// mode ([kDebugMode]); in release builds emission is a no-op regardless of
/// the flag, so instrumentation can be left wired up in production code.
///
/// ```dart
/// AmoebaGridDiagnostics.enabled = true;
/// AmoebaGridDiagnostics.events.listen(print);
/// // or simply:
/// AmoebaGridDiagnostics.attachDebugPrintLogger();
/// ```
abstract final class AmoebaGridDiagnostics {
  /// Master switch. Only honored in debug mode.
  static bool enabled = false;

  static bool get isActive => kDebugMode && enabled;

  /// Paints every card's shape-following padding band — the ring between
  /// its outline and the outline eroded by [paddingOverlayInset] — in
  /// translucent red, so content overlapping the padding is immediately
  /// visible. Debug mode only.
  static bool showPaddingOverlay = false;

  /// Erosion depth visualized by [showPaddingOverlay].
  static double paddingOverlayInset = 12;

  static final StreamController<AmoebaGridEvent> _controller =
      StreamController<AmoebaGridEvent>.broadcast();

  /// Broadcast stream of grid events (empty unless [isActive]).
  static Stream<AmoebaGridEvent> get events => _controller.stream;

  static StreamSubscription<AmoebaGridEvent>? _printSubscription;

  /// Pipes every event through [debugPrint] with a `[amoeba_grid]` prefix.
  static void attachDebugPrintLogger() {
    _printSubscription ??=
        events.listen((e) => debugPrint('[amoeba_grid] $e'));
  }

  static void detachDebugPrintLogger() {
    _printSubscription?.cancel();
    _printSubscription = null;
  }

  /// Emits an event. Cheap no-op when inactive; callers on hot paths should
  /// still prefer checking [isActive] before building expensive `data` maps.
  static void emit(
    AmoebaGridEventKind kind,
    String message, [
    Map<String, Object?> data = const {},
  ]) {
    if (!isActive) return;
    _controller.add(AmoebaGridEvent(kind, message, data: data));
  }
}
