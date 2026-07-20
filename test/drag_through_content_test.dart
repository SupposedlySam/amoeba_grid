import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amoeba_grid/amoeba_grid.dart';

void main() {
  testWidgets('card drags when grabbed through hit-opaque content',
      (tester) async {
    const config = AmoebaGridConfig(
        columns: 8, rows: 8, gap: 10, minCellExtent: 80, maxCellExtent: 80);
    final controller = AmoebaGridController(config: config);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AmoebaGridView(
          controller: controller,
          cards: [
            AmoebaGridCard(
              id: 'a',
              initialShape: CardShape.rect(0, 0, 2, 2),
              child: InkWell(
                onTap: () {},
                child: const Center(child: Text('CONTENT')),
              ),
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final metrics = controller.metrics!;
    final pitch = metrics.pitch;
    // Drag starting exactly on the Text (hit-opaque content).
    final textCenter = tester.getCenter(find.text('CONTENT'));
    final gesture = await tester.startGesture(textCenter);
    await gesture.moveBy(Offset(pitch * 2.1, 0), timeStamp: const Duration(milliseconds: 100));
    await tester.pump();
    final dragging = controller.isDragging;
    await gesture.up();
    await tester.pumpAndSettle();

    expect(dragging, isTrue, reason: 'drag session should be live mid-move');
    expect(controller.committedShape('a'), CardShape.rect(2, 0, 2, 2));
  });
}
