import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:folder_sync/main.dart';

void main() {
  testWidgets('App opens splash and navigates to dashboard', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const FtpBackupApp());

    expect(find.text('FTP Backup'), findsOneWidget);
    expect(find.text('Version 1.0.0'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('System Status'), findsOneWidget);
    expect(find.text('Configure FTP connections'), findsOneWidget);
    expect(find.text('Create and manage backup jobs'), findsOneWidget);
    expect(find.text('Mirror and two-way sync'), findsOneWidget);

    await tester.tap(find.text('Mirror and two-way sync'));
    await tester.pumpAndSettle();

    expect(find.text('No Sync Rules'), findsOneWidget);
    expect(
      find.text('Add an FTP server first, then create a sync rule.'),
      findsOneWidget,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create and manage backup jobs'));
    await tester.pumpAndSettle();

    expect(find.text('No Backup Jobs'), findsOneWidget);
    expect(
      find.text('Add an FTP server first, then create a backup job.'),
      findsOneWidget,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Configure FTP connections'));
    await tester.pumpAndSettle();

    expect(find.text('No FTP Servers'), findsOneWidget);

    await tester.tap(find.byTooltip('Add FTP Server'));
    await tester.pumpAndSettle();

    await tester.enterText(find.bySemanticsLabel('Server Name'), 'Test FTP');
    await tester.enterText(
      find.bySemanticsLabel('Host / IP Address'),
      'ftp.test.local',
    );
    await tester.enterText(find.bySemanticsLabel('Username'), 'backup_user');

    await tester.drag(find.byType(ListView).last, const Offset(0, -240));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save FTP Server'));
    await tester.pumpAndSettle();

    expect(find.text('Test FTP'), findsOneWidget);
    expect(find.text('ftp.test.local:21 - backup_user'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit FTP Server'));
    await tester.pumpAndSettle();

    expect(find.text('Edit FTP Server'), findsOneWidget);

    await tester.enterText(find.bySemanticsLabel('Server Name'), 'Office FTP');
    await tester.drag(find.byType(ListView).last, const Offset(0, -240));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Update FTP Server'));
    await tester.pumpAndSettle();

    expect(find.text('Office FTP'), findsOneWidget);
    expect(find.text('Test FTP'), findsNothing);

    await tester.tap(find.byTooltip('Delete FTP Server'));
    await tester.pumpAndSettle();

    expect(find.text('Delete FTP Server'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('No FTP Servers'), findsOneWidget);
    expect(find.text('Office FTP'), findsNothing);
  });
}
