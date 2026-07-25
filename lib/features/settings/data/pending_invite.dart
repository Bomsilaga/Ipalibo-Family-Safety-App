import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// An invite code captured from a shared link (`/join?code=…`) before the
/// invitee has an account.
///
/// It has to outlive the sign-up round trip: Supabase requires email
/// confirmation on this project, so an invitee opens the link, signs up,
/// leaves for their inbox, clicks the confirmation, and comes back through
/// a *fresh page load*. In-memory state doesn't survive that, which is why
/// this is persisted rather than held in a provider. Cleared as soon as
/// it's redeemed (or if it turns out to be invalid) so a stale code can't
/// hijack a later, unrelated sign-up on the same device.
class PendingInviteStore {
  PendingInviteStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _codeKey = 'pending_invite_code';

  Future<String?> read() => _storage.read(key: _codeKey);

  Future<void> save(String code) =>
      _storage.write(key: _codeKey, value: code.trim().toUpperCase());

  Future<void> clear() => _storage.delete(key: _codeKey);
}

final pendingInviteStoreProvider = Provider<PendingInviteStore>((ref) {
  return PendingInviteStore();
});

/// Non-null while an invite is waiting to be redeemed — drives the "You've
/// been invited" banner on the sign-in screen and the auto-join on
/// family setup. Invalidate after redeeming.
final pendingInviteCodeProvider = FutureProvider<String?>((ref) {
  return ref.watch(pendingInviteStoreProvider).read();
});
