import 'package:flutter_test/flutter_test.dart';
import 'package:folder_sync/features/repositories/sync_rule_repository.dart';
import 'package:folder_sync/features/sync/models/sync_rule_model.dart';

void main() {
  group('SyncRuleRepository remote diff decisions', () {
    final repository = SyncRuleRepository.instance;
    final older = DateTime(2026, 1, 1, 12);
    final newer = DateTime(2026, 1, 1, 12, 1);
    final nearSame = DateTime(2026, 1, 1, 12, 0, 1);

    test('skips matching files for forced conflict rules', () {
      expect(
        repository.shouldUploadForTest(
          localSize: 10,
          localModifiedAt: older,
          remoteSize: 10,
          remoteModifiedAt: older,
          conflictRule: SyncConflictRule.localWins,
        ),
        isFalse,
      );

      expect(
        repository.shouldDownloadForTest(
          localSize: 10,
          localModifiedAt: older,
          remoteSize: 10,
          remoteModifiedAt: older,
          conflictRule: SyncConflictRule.remoteWins,
        ),
        isFalse,
      );
    });

    test('detects newer same-size files when timestamps differ clearly', () {
      expect(
        repository.shouldUploadForTest(
          localSize: 10,
          localModifiedAt: newer,
          remoteSize: 10,
          remoteModifiedAt: older,
          conflictRule: SyncConflictRule.newerWins,
        ),
        isTrue,
      );

      expect(
        repository.shouldDownloadForTest(
          localSize: 10,
          localModifiedAt: older,
          remoteSize: 10,
          remoteModifiedAt: newer,
          conflictRule: SyncConflictRule.newerWins,
        ),
        isTrue,
      );
    });

    test('ignores tiny remote timestamp rounding differences', () {
      expect(
        repository.shouldUploadForTest(
          localSize: 10,
          localModifiedAt: nearSame,
          remoteSize: 10,
          remoteModifiedAt: older,
          conflictRule: SyncConflictRule.newerWins,
        ),
        isFalse,
      );
    });

    test('transfers missing or different-size files', () {
      expect(
        repository.shouldUploadForTest(
          localSize: 10,
          localModifiedAt: older,
          remoteSize: null,
          remoteModifiedAt: null,
          conflictRule: SyncConflictRule.skip,
        ),
        isTrue,
      );

      expect(
        repository.shouldDownloadForTest(
          localSize: 10,
          localModifiedAt: older,
          remoteSize: 20,
          remoteModifiedAt: newer,
          conflictRule: SyncConflictRule.remoteWins,
        ),
        isTrue,
      );
    });
  });
}
