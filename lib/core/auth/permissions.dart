import 'app_user.dart';
import 'user_role.dart';

/// Every permission-gated action in the app, drawn from the permission
/// matrix in docs/01-product-spec.md §2. Add new actions here as new
/// modules land — never scatter `if (user.role == ...)` checks elsewhere.
enum AppAction {
  createFamily,
  inviteMember,
  promoteParent,
  createChildAccount,
  deleteFamily,
  editAnyCalendarEvent,
  editOwnCalendarEvent,
  disableGpsSharing,
  createTasks,
  completeOwnTasks,
  viewReports,
  configureAutomation,
  manageScreenTime,
  approveUnlockRequest,
  requestUnlock,
  manageRewards,
  earnOrRedeemRewards,
  emergencySos,
}

/// Which roles may perform each [AppAction]. This is the single source of
/// truth for authorization UX; the real security boundary is Postgres RLS
/// (docs/03-architecture.md §3) — this helper must never be trusted alone.
const Map<AppAction, Set<UserRole>> _permissionMatrix = {
  AppAction.createFamily: {UserRole.parent},
  AppAction.inviteMember: {UserRole.parent},
  AppAction.promoteParent: {UserRole.parent},
  AppAction.createChildAccount: {UserRole.parent},
  AppAction.deleteFamily: {UserRole.parent},
  AppAction.editAnyCalendarEvent: {UserRole.parent},
  AppAction.editOwnCalendarEvent: {UserRole.parent, UserRole.child},
  AppAction.disableGpsSharing: {UserRole.parent},
  AppAction.createTasks: {UserRole.parent},
  AppAction.completeOwnTasks: {UserRole.parent, UserRole.child},
  AppAction.viewReports: {UserRole.parent},
  AppAction.configureAutomation: {UserRole.parent},
  AppAction.manageScreenTime: {UserRole.parent},
  AppAction.approveUnlockRequest: {UserRole.parent},
  AppAction.requestUnlock: {UserRole.parent, UserRole.child},
  AppAction.manageRewards: {UserRole.parent},
  AppAction.earnOrRedeemRewards: {UserRole.parent, UserRole.child},
  AppAction.emergencySos: {UserRole.parent, UserRole.child},
};

/// The one and only place that decides whether [user] may perform [action].
/// Backed by [_permissionMatrix] — see docs/01-product-spec.md §2.
bool hasPermission(AppUser user, AppAction action) {
  final allowedRoles = _permissionMatrix[action];
  if (allowedRoles == null) return false;
  return allowedRoles.contains(user.role);
}
