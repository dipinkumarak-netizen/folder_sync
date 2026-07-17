import 'package:flutter_test/flutter_test.dart';

import 'package:folder_sync/main.dart';

void main() {
  testWidgets('App opens splash and navigates to dashboard', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const FtpBackupApp());

    expect(find.text('FTP Backup'), findsOneWidget);
    expect(find.text('Version 1.0.0'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('System Status'), findsOneWidget);
    expect(find.text('Configure FTP connections'), findsOneWidget);
  });
}
