import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:folder_sync/main.dart';
import 'package:folder_sync/features/ftp/widgets/remote_folder_picker_field.dart';

void main() {
  Future<void> tapDashboardCard(WidgetTester tester, String subtitle) async {
    await tester.scrollUntilVisible(
      find.text(subtitle),
      320,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(subtitle));
    await tester.pumpAndSettle();
  }

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
    await tester.pump();

    expect(
      find.text(
        'Prepare storage, notifications, Wi-Fi checks, and scheduling before your first backup.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();

    expect(find.text('System Status'), findsOneWidget);
    expect(find.text('Configure FTP and SFTP connections'), findsOneWidget);
    expect(find.text('Create and manage backup jobs'), findsOneWidget);
    expect(find.text('Mirror and two-way sync'), findsOneWidget);
    expect(find.text('Backup history and logs'), findsOneWidget);

    await tapDashboardCard(tester, 'Backup history and logs');

    expect(find.text('No History Yet'), findsOneWidget);
    expect(
      find.text(
        'Completed backup, sync, and restore operations will appear here.',
      ),
      findsOneWidget,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tapDashboardCard(tester, 'Mirror and two-way sync');

    expect(find.text('No Sync Rules'), findsOneWidget);
    expect(
      find.text('Add an FTP server first, then create a sync rule.'),
      findsOneWidget,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tapDashboardCard(tester, 'Create and manage backup jobs');

    expect(find.text('No Backup Jobs'), findsOneWidget);
    expect(
      find.text('Add an FTP server first, then create a backup job.'),
      findsOneWidget,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tapDashboardCard(tester, 'Configure FTP and SFTP connections');

    expect(find.text('No Connections'), findsOneWidget);

    await tester.tap(find.byTooltip('Add Connection'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('FTP'));
    await tester.pumpAndSettle();

    await tester.enterText(find.bySemanticsLabel('Server Name'), 'Test FTP');
    await tester.enterText(
      find.bySemanticsLabel('Host / IP Address'),
      'ftp.test.local',
    );
    await tester.enterText(find.bySemanticsLabel('Username'), 'backup_user');
    await tester.pump();

    final remoteFolderField = tester.widget<RemoteFolderPickerField>(
      find.byType(RemoteFolderPickerField),
    );
    expect(remoteFolderField.ftpServer, isNotNull);
    expect(remoteFolderField.ftpServer!.host, 'ftp.test.local');
    expect(remoteFolderField.ftpServer!.username, 'backup_user');

    await tester.drag(find.byType(ListView).last, const Offset(0, -240));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save FTP Server'));
    await tester.pumpAndSettle();

    expect(find.text('Test FTP'), findsOneWidget);
    expect(find.text('ftp.test.local:21 - backup_user'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit Connection'));
    await tester.pumpAndSettle();

    expect(find.text('Edit FTP Connection'), findsOneWidget);

    await tester.enterText(find.bySemanticsLabel('Server Name'), 'Office FTP');
    await tester.drag(find.byType(ListView).last, const Offset(0, -240));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Update FTP Server'));
    await tester.pumpAndSettle();

    expect(find.text('Office FTP'), findsOneWidget);
    expect(find.text('Test FTP'), findsNothing);

    await tester.tap(find.byTooltip('Delete Connection'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Connection'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('No Connections'), findsOneWidget);
    expect(find.text('Office FTP'), findsNothing);
  });
}
