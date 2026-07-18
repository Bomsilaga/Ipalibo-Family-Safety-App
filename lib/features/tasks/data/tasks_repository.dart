import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_client.dart';
import '../domain/task_model.dart';

class TasksRepository {
  TasksRepository(this._client);

  final SupabaseClient _client;

  Future<List<TaskModel>> tasksDueOn(DateTime day) async {
    final iso = day.toIso8601String().substring(0, 10);
    final rows = await _client
        .from('tasks')
        .select('*, task_assignees(user_id)')
        .eq('due_date', iso)
        .order('due_time');
    return (rows as List).map((r) => TaskModel.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<List<TaskModel>> allOpenTasks() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final rows = await _client
        .from('tasks')
        .select('*, task_assignees(user_id)')
        .gte('due_date', today)
        .order('due_date')
        .order('due_time');
    return (rows as List).map((r) => TaskModel.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<Map<String, TaskCompletion>> completionsFor(
      List<String> taskIds, String userId, DateTime day) async {
    if (taskIds.isEmpty) return {};
    final iso = day.toIso8601String().substring(0, 10);
    final rows = await _client
        .from('task_completions')
        .select()
        .inFilter('task_id', taskIds)
        .eq('user_id', userId)
        .eq('scheduled_date', iso);
    return {
      for (final r in rows as List)
        (r as Map<String, dynamic>)['task_id'] as String: TaskCompletion.fromJson(r),
    };
  }

  /// "I've Completed This": upserts the completion row for today's
  /// occurrence. Status is completed or late depending on when the tap
  /// happens relative to due time + grace (product spec §6).
  Future<TaskCompletion> completeTask({
    required TaskModel task,
    required String userId,
    String? evidenceNote,
    String? evidencePhotoUrl,
  }) async {
    final now = DateTime.now();
    final late = now.isAfter(task.dueAt.add(Duration(minutes: task.gracePeriodMinutes)));
    final row = await _client
        .from('task_completions')
        .upsert({
          'task_id': task.id,
          'user_id': userId,
          'scheduled_date': now.toIso8601String().substring(0, 10),
          'status': late ? 'late' : 'completed',
          'completed_at': now.toUtc().toIso8601String(),
          if (evidenceNote != null) 'evidence_note': evidenceNote,
          if (evidencePhotoUrl != null) 'evidence_photo_url': evidencePhotoUrl,
        }, onConflict: 'task_id,user_id,scheduled_date')
        .select()
        .single();
    return TaskCompletion.fromJson(row);
  }

  /// Parent approval — flips an approval-gated completion to approved and
  /// (if the task carries a reward) writes the points to the ledger.
  Future<void> approveCompletion({
    required TaskCompletion completion,
    required String parentId,
    required String familyId,
    int? rewardPoints,
  }) async {
    await _client.from('task_completions').update({
      'status': 'approved',
      'approved_by': parentId,
      'approved_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', completion.id);

    if (rewardPoints != null && rewardPoints > 0) {
      await _client.from('reward_ledger').insert({
        'family_id': familyId,
        'user_id': completion.userId,
        'points': rewardPoints,
        'reason': 'Task approved',
        'related_type': 'task_completion',
        'related_id': completion.id,
      });
    }
  }

  Future<TaskModel> createTask({
    required String familyId,
    required String createdBy,
    required String title,
    required String category,
    required DateTime dueDate,
    required String dueTime,
    String? description,
    String? instructions,
    int gracePeriodMinutes = 90,
    String? repeatRule,
    bool requiresApproval = false,
    bool requiresEvidence = false,
    String? subject,
    String? bookTitle,
    required List<String> assigneeIds,
  }) async {
    final row = await _client
        .from('tasks')
        .insert({
          'family_id': familyId,
          'created_by': createdBy,
          'title': title,
          'description': description,
          'instructions_rich': instructions,
          'category': category,
          'due_date': dueDate.toIso8601String().substring(0, 10),
          'due_time': dueTime,
          'grace_period_minutes': gracePeriodMinutes,
          'repeat_rule': repeatRule,
          'requires_approval': requiresApproval,
          'requires_evidence': requiresEvidence,
          'subject': subject,
          'book_title': bookTitle,
        })
        .select()
        .single();

    // Bulk assignment: one task, many children (product spec §6).
    if (assigneeIds.isNotEmpty) {
      await _client.from('task_assignees').insert([
        for (final userId in assigneeIds) {'task_id': row['id'], 'user_id': userId},
      ]);
    }
    return TaskModel.fromJson({...row, 'task_assignees': []});
  }
}

final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  return TasksRepository(supabase);
});

final openTasksProvider = FutureProvider<List<TaskModel>>((ref) async {
  return ref.watch(tasksRepositoryProvider).allOpenTasks();
});
