import 'package:flutter_test/flutter_test.dart';
import 'package:ipalibos/features/tasks/domain/task_model.dart';

TaskModel _task({String dueTime = '17:00:00', int grace = 90}) => TaskModel(
      id: 't1',
      familyId: 'f1',
      createdBy: 'p1',
      title: 'Clean room',
      category: 'chore',
      dueDate: DateTime(2026, 7, 17),
      dueTime: dueTime,
      gracePeriodMinutes: grace,
    );

void main() {
  group('deriveStatus lifecycle (Upcoming → Due → Missed)', () {
    test('before due time is upcoming', () {
      expect(deriveStatus(_task(), DateTime(2026, 7, 17, 16, 0)), 'upcoming');
    });

    test('inside the grace window is due', () {
      expect(deriveStatus(_task(), DateTime(2026, 7, 17, 17, 30)), 'due');
      expect(deriveStatus(_task(), DateTime(2026, 7, 17, 18, 29)), 'due');
    });

    test('past due time + grace period is missed', () {
      expect(deriveStatus(_task(), DateTime(2026, 7, 17, 18, 31)), 'missed');
    });
  });

  test('TaskModel parses reading/homework fields and assignees', () {
    final task = TaskModel.fromJson({
      'id': 't2',
      'family_id': 'f1',
      'created_by': 'p1',
      'title': 'Read 20 pages',
      'category': 'reading',
      'due_date': '2026-07-18',
      'due_time': '19:00:00',
      'book_title': 'Charlotte\'s Web',
      'target_pages': 20,
      'task_assignees': [
        {'user_id': 'c1'},
        {'user_id': 'c2'},
      ],
    });
    expect(task.bookTitle, 'Charlotte\'s Web');
    expect(task.targetPages, 20);
    expect(task.assigneeIds, ['c1', 'c2']);
    expect(task.dueAt, DateTime(2026, 7, 18, 19, 0));
  });
}
