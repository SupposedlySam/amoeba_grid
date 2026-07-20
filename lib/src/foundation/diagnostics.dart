import 'dart:async';

import 'package:flutter/foundation.dart';

/// Categories of instrumentation events emitted by the grid.
enum LiquidGridEventKind {
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
class LiquidGridEvent {
  const LiquidGridEvent(this.kind, this.message, {this.data = const {}});

  final LiquidGridEventKind kind;
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
/// LiquidGridDiagnostics.enabled = true;
/// LiquidGridDiagnostics.events.listen(print);
/// // or simply:
/// LiquidGridDiagnostics.attachDebugPrintLogger();
/// ```
abstract final class LiquidGridDiagnostics {
  /// Master switch. Only honored in debug mode.
  static bool enabled = false;

  static bool get isActive => kDebugMode && enabled;

  static final StreamController<LiquidGridEvent> _controller =
      StreamController<LiquidGridEvent>.broadcast();

  /// Broadcast stream of grid events (empty unless [isActive]).
  static Stream<LiquidGridEvent> get events => _controller.stream;

  static StreamSubscription<LiquidGridEvent>? _printSubscription;

  /// Pipes every event through [debugPrint] with a `[liquid_grid]` prefix.
  static void attachDebugPrintLogger() {
    _printSubscription ??=
        events.listen((e) => debugPrint('[liquid_grid] $e'));
  }

  static void detachDebugPrintLogger() {
    _printSubscription?.cancel();
    _printSubscription = null;
  }

  /// Emits an event. Cheap no-op when inactive; callers on hot paths should
  /// still prefer checking [isActive] before building expensive `data` maps.
  static void emit(
    LiquidGridEventKind kind,
    String message, [
    Map<String, Object?> data = const {},
  ]) {
    if (!isActive) return;
    _controller.add(LiquidGridEvent(kind, message, data: data));
  }
}
