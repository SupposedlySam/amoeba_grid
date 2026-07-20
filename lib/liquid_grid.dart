/// A fluid, draggable dashboard grid for Flutter.
///
/// Cards live on a fixed field of square units, can be reshaped strip-by-
/// strip into organic polyomino silhouettes via edge and corner handles,
/// pushed through each other amoeba-style, and their user shaping persists
/// per viewport-width breakpoint.
library;

export 'src/controller.dart' show DragKind, DragSession, LiquidGridController;
export 'src/engine/content_geometry.dart'
    show LiquidBand, LiquidCardGeometry, LiquidRegion;
export 'src/engine/drag_engine.dart' show SubmissiveState;
export 'src/engine/grid_metrics.dart' show GridMetrics;
export 'src/engine/handles.dart' show GridHandle;
export 'src/foundation/cell.dart'
    show CardShape, CardinalEdge, CellIndex, CornerKind;
export 'src/foundation/config.dart' show LiquidGridConfig;
export 'src/foundation/diagnostics.dart'
    show LiquidGridDiagnostics, LiquidGridEvent, LiquidGridEventKind;
export 'src/foundation/storage.dart'
    show
        LiquidGridLayoutData,
        LiquidGridLayoutStore,
        LiquidGridMemoryStorage,
        LiquidGridStorage;
export 'src/widgets/card_chrome.dart' show LiquidGridStyle;
export 'src/widgets/liquid_card_scope.dart'
    show LiquidCardScope, LiquidContentArea, LiquidPadding, LiquidRegions;
export 'src/widgets/liquid_flow.dart'
    show LiquidColumn, LiquidFlow, LiquidFlowAlignment, LiquidRow;
export 'src/widgets/liquid_grid_view.dart' show LiquidGridCard, LiquidGridView;
export 'src/widgets/liquid_text.dart' show LiquidText;
