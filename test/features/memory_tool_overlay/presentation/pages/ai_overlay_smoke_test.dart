import 'package:JsxposedX/features/memory_tool_overlay/presentation/pages/ai_overlay/ai_overlay.dart';
import 'package:JsxposedX/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  testWidgets('ai overlay renders empty state without selected process', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AiOverlay(),
          ),
        ),
      ),
    );

    expect(find.byType(AiOverlay), findsOneWidget);
  });
}
