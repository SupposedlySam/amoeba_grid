# amoeba_grid

An amoeba dashboard grid for Flutter. Cards live on a fixed field of
square units, reshape **strip-by-strip into organic polyomino silhouettes**,
push through each other **amoeba-style**, and remember the user's shaping per
viewport breakpoint.

Built for bento-style dashboards: dark-mode friendly, gap-respecting, and
rendered with `CustomPainter` outlines (proper inside/outside corner radii on
non-rectangular shapes).

## Highlights

- **Amoeba grid, fluid cells** — you configure minimum `columns x rows`; the
  square cell extent flexes between `minCellExtent` and `maxCellExtent` to
  fill the viewport, and when there's room for more whole units at max
  extent, the field grows extra columns/rows to match the window. When even
  the minimum can't fit, the field pans in both axes (spreadsheet-style,
  powered by `TwoDimensionalScrollable`).
- **Cards are not just rectangles** — every open cell edge exposes a
  semicircular grab handle (progressively revealed on hover); dragging one
  extends or retracts *just that row/column strip*, and dragging
  perpendicular mid-gesture grows only the newly carved section (L-shaped
  drags). Corners — convex *and* concave — use standard both-axes rules
  with quarter-circle affordances that respect the corner radii.
- **50% snap previews** — dragging past the midpoint of the next column/row
  (gap midpoints included) snaps a preview outline; releasing commits it.
- **Aggressor / submissive collisions** — drag a card through another and the
  other card's edge defers like an amoeba: it cedes cells from the edge the
  aggressor hit (decided edge-to-edge at contact, and re-decided on every
  fresh contact within the same drag), reverts the moment you pass beyond it
  (transient values), and records its ceded shape as its own if you drop
  while overlapping. A card that would shrink below 1x1 jumps to the side
  opposite the aggressor instead.
- **Gaps always respected** — identical horizontal/vertical gutters between
  islands, including self-adjacent diagonal pinches.
- **Persistence with breakpoints** — user shaping is stored against the
  viewport-width breakpoint it was made at and resolved mobile-first, so a
  narrow window and a wide window can hold different layouts. Storage is a
  two-method interface; bring `shared_preferences`, a file, or a server.
- **Deep instrumentation, debug-only** — every hover, snap, trim, relocation,
  commit, and persistence event streams from `AmoebaGridDiagnostics`, gated
  behind a flag that is inert in release builds.

## Usage

```dart
final controller = AmoebaGridController(
  config: const AmoebaGridConfig(
    columns: 8,
    rows: 12,
    minCellExtent: 68,
    maxCellExtent: 128,
    gap: 12,
    insideCornerRadius: 12,
    outsideCornerRadius: 24,
  ),
  storage: MyPrefsStorage(), // optional; defaults to in-memory
);

AmoebaGridView(
  controller: controller,
  cards: [
    AmoebaGridCard(
      id: 'revenue',
      initialShape: CardShape.rect(0, 0, 3, 2), // user shaping overrides this
      child: const RevenueCard(),
    ),
    // ...
  ],
);
```

Persistence is two methods:

```dart
class MyPrefsStorage implements AmoebaGridStorage {
  @override
  Future<String?> read(String key) async => ...;
  @override
  Future<void> write(String key, String value) async => ...;
}
```

Instrumentation:

```dart
if (kDebugMode) {
  AmoebaGridDiagnostics.enabled = true;           // inert in release builds
  AmoebaGridDiagnostics.events.listen(onEvent);   // structured event stream
  // or AmoebaGridDiagnostics.attachDebugPrintLogger();
}
```

## Shape-aware content

Flutter's layout protocol is rectangular (`BoxConstraints`), so plain
widgets can't flow around a notch — but amoeba shapes are cell-quantized,
which makes shape-aware layout tractable. Every card's child is wrapped in
a `AmoebaCardScope` publishing its `AmoebaCardGeometry` (bands, largest
inscribed rectangle, maximal-rectangle regions), and a small family of
content widgets builds on it:

| Widget | What it does |
| --- | --- |
| `AmoebaContentArea` | SafeArea for notches: lays its child in the largest rectangle fully inside the shape |
| `AmoebaRegions` | One builder call per rectangular sub-region of the shape (area-descending) |
| `AmoebaColumn` / `AmoebaRow` / `AmoebaFlow` | Flow children along an axis, constraining each to the free span at its position |
| `AmoebaText` | Text that wraps band-by-band around notches (a `shape-outside` equivalent) |
| `AmoebaPadding` | Padding that republishes correctly-deflated geometry to fluid widgets below |

All of them degrade gracefully to plain rectangular behavior outside a
amoeba card. Content is laid out against the settled target shape while the
morph clip animates, so reshaping never causes per-frame reflow jitter.

```dart
AmoebaGridCard(
  id: 'notes',
  initialShape: CardShape.rect(2, 4, 3, 3),
  child: AmoebaPadding(
    padding: const EdgeInsets.all(16),
    child: AmoebaText('Words flow around whatever you carve…'),
  ),
);
```

## Interaction model

| Gesture | Result |
| --- | --- |
| Drag card body | Move the whole card; snapped preview at 50% crossings |
| Drag side handle | Extend/retract that single row/column strip |
| ...then drag perpendicular | Grow only the new section in that direction |
| Drag corner handle (convex or concave) | Standard corner resize: both edge segments through the corner |
| Drag near viewport edge | Auto-pans the field under the drag |
| Background drag / trackpad scroll | Pan the whole field in both axes |
| <kbd>Esc</kbd> during a drag | Cancel and revert everything |

## Example

`example/` contains a bento-style dashboard (macOS + web) with live config
sliders (gap, radii, cell extents), a diagnostics console overlay, and
`shared_preferences` persistence. Run it with:

```sh
cd example && flutter run -d macos
```

## Status

Early release. The API surface (`AmoebaGridConfig`, `AmoebaGridController`,
`AmoebaGridCard`, `AmoebaGridStorage`, `AmoebaGridDiagnostics`) is small on
purpose; feedback welcome.
