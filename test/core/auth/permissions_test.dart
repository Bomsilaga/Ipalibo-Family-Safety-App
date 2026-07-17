import 'package:flutter_test/flutter_test.dart';
import 'package:ipalibos/core/auth/app_user.dart';
import 'package:ipalibos/core/auth/permissions.dart';
import 'package:ipalibos/core/auth/user_role.dart';

AppUser _user(UserRole role) => AppUser(
      id: 'u1',
      familyId: 'f1',
      role: role,
      displayName: 'Test',
      avatarColor: '#23907F',
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  group('hasPermission', () {
    final parent = _user(UserRole.parent);
    final child = _user(UserRole.child);

    test('only a parent can invite members', () {
      expect(hasPermission(parent, AppAction.inviteMember), isTrue);
      expect(hasPermission(child, AppAction.inviteMember), isFalse);
    });

    test('only a parent can create a child account', () {
      expect(hasPermission(parent, AppAction.createChildAccount), isTrue);
      expect(hasPermission(child, AppAction.createChildAccount), isFalse);
    });

    test('only a parent can disable GPS sharing — a child cannot turn it off', () {
      expect(hasPermission(parent, AppAction.disableGpsSharing), isTrue);
      expect(hasPermission(child, AppAction.disableGpsSharing), isFalse);
    });

    test('both roles can send an emergency SOS', () {
      expect(hasPermission(parent, AppAction.emergencySos), isTrue);
      expect(hasPermission(child, AppAction.emergencySos), isTrue);
    });

    test('a child may request unlock but not approve it', () {
      expect(hasPermission(child, AppAction.requestUnlock), isTrue);
      expect(hasPermission(child, AppAction.approveUnlockRequest), isFalse);
      expect(hasPermission(parent, AppAction.approveUnlockRequest), isTrue);
    });

    test('a child may edit their own calendar event but not everyone\'s', () {
      expect(hasPermission(child, AppAction.editOwnCalendarEvent), isTrue);
      expect(hasPermission(child, AppAction.editAnyCalendarEvent), isFalse);
      expect(hasPermission(parent, AppAction.editAnyCalendarEvent), isTrue);
    });
  });
}
