import 'package:flutter_test/flutter_test.dart';
import 'package:study_verse/models/group.dart';
import 'package:study_verse/models/resource.dart';
import 'package:study_verse/models/meeting.dart';
import 'package:study_verse/viewmodels/group_view_model.dart';
import 'package:study_verse/models/message.dart';
void main() {
  group('F01 — Group.generateCode()', () {
    test('le code fait exactement 6 caractères', () {
      final code = Group.generateCode();
      expect(code.length, equals(6));
    });

    test('le code ne contient que majuscules et chiffres', () {
      final code = Group.generateCode();
      expect(code, matches(RegExp(r'^[A-Z0-9]{6}$')));
    });

    test('deux codes successifs sont différents', () {
      final code1 = Group.generateCode();
      final code2 = Group.generateCode();
      expect(code1, isNot(equals(code2)));
    });
  });

  group('F01 — Valider code d\'invitation', () {
    test('code vide → false', () {
      final vm = GroupViewModel();
      expect(vm.validerCodeInvitation(''), isFalse);
      expect(vm.error, isNotNull);
    });

    test('code trop court → false', () {
      final vm = GroupViewModel();
      expect(vm.validerCodeInvitation('ABC'), isFalse);
    });

    test('code avec caractères invalides → false', () {
      final vm = GroupViewModel();
      expect(vm.validerCodeInvitation('abc!!!'), isFalse);
    });

    test('code valide ABC123 → true', () {
      final vm = GroupViewModel();
      expect(vm.validerCodeInvitation('ABC123'), isTrue);
    });

    test('code minuscule abc123 → true (converti auto)', () {
      final vm = GroupViewModel();
      expect(vm.validerCodeInvitation('abc123'), isTrue);
    });
  });

  group('Message — getFormattedTime()', () {
    test('retourne le format HH:mm', () {
      final msg = _makeMessage(DateTime(2025, 1, 1, 9, 5));
      expect(msg.getFormattedTime(), equals('09:05'));
    });
  });

  group('Meeting — isFuture() et getFormattedDate()', () {
    test('réunion dans le futur → true', () {
      final m = _makeMeeting(DateTime.now().add(const Duration(days: 1)));
      expect(m.isFuture(), isTrue);
    });

    test('réunion passée → false', () {
      final m = _makeMeeting(DateTime.now().subtract(const Duration(days: 1)));
      expect(m.isFuture(), isFalse);
    });

    test('getFormattedDate retourne le bon format', () {
      final m = _makeMeeting(DateTime(2025, 6, 15, 14, 30));
      expect(m.getFormattedDate(), contains('15/06/2025'));
    });
  });

  group('Resource — isUrl()', () {
    test('URL valide → true', () {
      final r = _makeResource('https://flutter.dev');
      expect(r.isUrl(), isTrue);
    });

    test('texte simple → false', () {
      final r = _makeResource('pas une url');
      expect(r.isUrl(), isFalse);
    });
  });

  group('Login — validation', () {
    test('nom vide → false', () async {
      final vm = GroupViewModel();
      expect(await vm.login(''), isFalse);
    });

    test('nom avec espaces → false', () async {
      final vm = GroupViewModel();
      expect(await vm.login('   '), isFalse);
    });
  });
}

// ── Helpers ───────────────────────────────────────────────────────────────────



Message _makeMessage(DateTime dt) => Message(
  id:        '1',
  groupId:   'g1',
  userId:    'u1',
  text:      'Hello',
  timestamp: dt.millisecondsSinceEpoch,
);

Meeting _makeMeeting(DateTime dt) => Meeting(
  id:      '1',
  groupId: 'g1',
  dateISO: dt.toIso8601String(),
  topic:   'Test',
);

Resource _makeResource(String url) => Resource(
  id:      '1',
  groupId: 'g1',
  title:   'Test',
  url:     url,
);