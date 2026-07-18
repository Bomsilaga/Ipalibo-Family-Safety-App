import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipalibos/core/theme/app_theme.dart';
import 'package:ipalibos/widgets/empty_state.dart';

void main() {
  testWidgets('EmptyState renders its message and optional action', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: EmptyState(
            icon: Icons.event_available_outlined,
            message: 'No appointments yet — tap + to add one.',
            actionLabel: 'Add appointment',
            onAction: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('No appointments yet — tap + to add one.'), findsOneWidget);
    expect(find.text('Add appointment'), findsOneWidget);

    await tester.tap(find.text('Add appointment'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('EmptyState with no action shows only the message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: EmptyState(icon: Icons.map_outlined, message: 'Nothing here yet.'),
        ),
      ),
    );

    expect(find.text('Nothing here yet.'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
  });
}
