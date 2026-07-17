/// The two v1 account types (docs/01-product-spec.md §2). A future `admin`
/// role is reserved but explicitly out of scope — do not add it speculatively.
enum UserRole {
  parent,
  child;

  static UserRole fromString(String value) => switch (value) {
        'parent' => UserRole.parent,
        'child' => UserRole.child,
        _ => throw ArgumentError('Unknown user role: $value'),
      };

  String toStringValue() => switch (this) {
        UserRole.parent => 'parent',
        UserRole.child => 'child',
      };
}
