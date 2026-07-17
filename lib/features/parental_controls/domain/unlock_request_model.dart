/// Mirrors `public.unlock_requests` (docs/02-data-model.md).
class UnlockRequest {
  const UnlockRequest({
    required this.id,
    required this.familyId,
    required this.childId,
    this.reason,
    required this.status,
    this.reviewedBy,
    this.reviewedAt,
    this.codeExpiresAt,
    this.codeUsedAt,
    this.attemptCount = 0,
    required this.createdAt,
  });

  final String id;
  final String familyId;
  final String childId;
  final String? reason;
  final String status; // pending | approved | temporary | rejected | expired
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime? codeExpiresAt;
  final DateTime? codeUsedAt;
  final int attemptCount;
  final DateTime createdAt;

  bool get isPending => status == 'pending';

  factory UnlockRequest.fromJson(Map<String, dynamic> json) => UnlockRequest(
        id: json['id'] as String,
        familyId: json['family_id'] as String,
        childId: json['child_id'] as String,
        reason: json['reason'] as String?,
        status: json['status'] as String,
        reviewedBy: json['reviewed_by'] as String?,
        reviewedAt: json['reviewed_at'] != null
            ? DateTime.parse(json['reviewed_at'] as String).toLocal()
            : null,
        codeExpiresAt: json['code_expires_at'] != null
            ? DateTime.parse(json['code_expires_at'] as String).toLocal()
            : null,
        codeUsedAt: json['code_used_at'] != null
            ? DateTime.parse(json['code_used_at'] as String).toLocal()
            : null,
        attemptCount: json['attempt_count'] as int? ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      );
}
