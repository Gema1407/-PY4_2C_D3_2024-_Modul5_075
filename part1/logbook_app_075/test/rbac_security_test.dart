import 'package:flutter_test/flutter_test.dart';
import 'package:logbook_app_075/features/logbook/models/log_model.dart';

void main() {
  group('RBAC Security: Data Privacy Tests', () {
    // Setup data: User A punya 2 catatan
    final logPrivate = LogModel(
      id: 'log_001',
      title: 'Catatan Rahasia',
      description: 'Isi privat',
      date: DateTime.now().toIso8601String(),
      authorId: 'user_A',
      teamId: 'team_A',
      isPublic: false, // PRIVATE
    );

    final logPublic = LogModel(
      id: 'log_002',
      title: 'Catatan Publik',
      description: 'Isi publik',
      date: DateTime.now().toIso8601String(),
      authorId: 'user_A',
      teamId: 'team_A',
      isPublic: true, // PUBLIC
    );

    final allLogs = [logPrivate, logPublic];
    const currentUserId = 'user_B'; // User B = rekan satu tim User A

    test(
      'RBAC Security Check: Private logs should NOT be visible to teammates',
      () {
        // Action: User B memanggil filter visibility
        final visibleToUserB = allLogs.where((log) {
          return log.authorId == currentUserId || log.isPublic == true;
        }).toList();

        // Assert: User B hanya melihat 1 log (yang Public)
        expect(
          visibleToUserB.length,
          equals(1),
          reason: 'User B seharusnya hanya melihat 1 log (yang Public)',
        );
        expect(
          visibleToUserB.first.id,
          equals('log_002'),
          reason: 'Log yang terlihat harus yang isPublic == true',
        );
        expect(
          visibleToUserB.any((l) => l.isPublic == false),
          isFalse,
          reason: 'Log Private tidak boleh bocor ke User B (VULNERABLE!)',
        );
      },
    );

    test('Owner-only: User B tidak boleh edit/hapus log milik User A', () {
      const editorId = 'user_B';

      // Data Sovereignty check: hanya authorId == editorId yang boleh edit
      final canEdit = logPrivate.authorId == editorId;
      final canDelete = logPrivate.authorId == editorId;

      expect(canEdit, isFalse, reason: 'User B tidak boleh edit log User A');
      expect(canDelete, isFalse, reason: 'User B tidak boleh hapus log User A');
    });

    test('Owner: User A bisa edit/hapus lognya sendiri', () {
      const ownerId = 'user_A';

      final canEdit = logPrivate.authorId == ownerId;
      final canDelete = logPrivate.authorId == ownerId;

      expect(canEdit, isTrue);
      expect(canDelete, isTrue);
    });
  });
}
