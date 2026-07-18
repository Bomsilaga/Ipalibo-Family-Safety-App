/// Mirrors `public.tasks` + its completion row for one occurrence
/// (docs/02-data-model.md "Tasks / Chores / Homework / Reading").
class TaskModel {
  const TaskModel({
    required this.id,
    required this.familyId,
    required this.createdBy,
    required this.title,
    this.description,
    this.instructionsRich,
    required this.category,
    this.priority = 'normal',
    required this.dueDate,
    required this.dueTime,
    this.gracePeriodMinutes = 90,
    this.repeatRule,
    this.requiresApproval = false,
    this.requiresEvidence = false,
    this.rewardId,
    this.bookTitle,
    this.targetMinutes,
    this.targetPages,
    this.subject,
    this.assigneeIds = const [],
  });

  final String id;
  final String familyId;
  final String createdBy;
  final String title;
  final String? description;
  final String? instructionsRich;
  final String category; // chore | reading | homework | other
  final String priority;
  final DateTime dueDate;
  final String dueTime; // HH:mm:ss as stored
  final int gracePeriodMinutes;
  final String? repeatRule;
  final bool requiresApproval;
  final bool requiresEvidence;
  final String? rewardId;
  final String? bookTitle;
  final int? targetMinutes;
  final int? targetPages;
  final String? subject;
  final List<String> assigneeIds;

  DateTime get dueAt {
    final parts = dueTime.split(':');
    return DateTime(dueDate.year, dueDate.month, dueDate.day,
        int.parse(parts[0]), int.parse(parts[1]));
  }

  factory TaskModel.fromJson(Map<String, dynamic> json) => TaskModel(
        id: json['id'] as String,
        familyId: json['family_id'] as String,
        createdBy: json['created_by'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        instructionsRich: json['instructions_rich'] as String?,
        category: json['category'] as String,
        priority: json['priority'] as String? ?? 'normal',
        dueDate: DateTime.parse(json['due_date'] as String),
        dueTime: json['due_time'] as String,
        gracePeriodMinutes: json['grace_period_minutes'] as int? ?? 90,
        repeatRule: json['repeat_rule'] as String?,
        requiresApproval: json['requires_approval'] as bool? ?? false,
        requiresEvidence: json['requires_evidence'] as bool? ?? false,
        rewardId: json['reward_id'] as String?,
        bookTitle: json['book_title'] as String?,
        targetMinutes: json['target_minutes'] as int?,
        targetPages: json['target_pages'] as int?,
        subject: json['subject'] as String?,
        assigneeIds: (json['task_assignees'] as List?)
                ?.map((e) => (e as Map<String, dynamic>)['user_id'] as String)
                .toList() ??
            const [],
      );
}

/// One occurrence's completion state for one assignee.
class TaskCompletion {
  const TaskCompletion({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.scheduledDate,
    required this.status,
    this.completedAt,
    this.evidencePhotoUrl,
    this.evidenceNote,
    this.approvedBy,
  });

  final String id;
  final String taskId;
  final String userId;
  final DateTime scheduledDate;
  final String status; // upcoming | due | completed | late | missed | approved
  final DateTime? completedAt;
  final String? evidencePhotoUrl;
  final String? evidenceNote;
  final String? approvedBy;

  factory TaskCompletion.fromJson(Map<String, dynamic> json) => TaskCompletion(
        id: json['id'] as String,
        taskId: json['task_id'] as String,
        userId: json['user_id'] as String,
        scheduledDate: DateTime.parse(json['scheduled_date'] as String),
        status: json['status'] as String,
        completedAt: json['completed_at'] != null
            ? DateTime.parse(json['completed_at'] as String).toLocal()
            : null,
        evidencePhotoUrl: json['evidence_photo_url'] as String?,
        evidenceNote: json['evidence_note'] as String?,
        approvedBy: json['approved_by'] as String?,
      );

  bool get isDone => status == 'completed' || status == 'approved';
}

/// Derives the display status for a task occurrence with no completion row
/// yet: Upcoming → Due → (past grace) Missed (product spec §6 lifecycle).
String deriveStatus(TaskModel task, DateTime now) {
  final due = task.dueAt;
  if (now.isBefore(due)) return 'upcoming';
  if (now.isBefore(due.add(Duration(minutes: task.gracePeriodMinutes)))) return 'due';
  return 'missed';
}
