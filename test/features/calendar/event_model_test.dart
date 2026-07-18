import 'package:flutter_test/flutter_test.dart';
import 'package:ipalibos/features/calendar/domain/event_model.dart';

EventModel _event(DateTime start, {DateTime? end, String id = 'e1'}) => EventModel(
      id: id,
      familyId: 'f1',
      ownerId: 'u1',
      title: 'Event',
      startAt: start,
      endAt: end,
    );

void main() {
  group('EventModel.overlaps (conflict detection)', () {
    test('overlapping windows conflict', () {
      final a = _event(DateTime(2026, 7, 17, 10), end: DateTime(2026, 7, 17, 11));
      final b = _event(DateTime(2026, 7, 17, 10, 30), end: DateTime(2026, 7, 17, 11, 30), id: 'e2');
      expect(a.overlaps(b), isTrue);
      expect(b.overlaps(a), isTrue);
    });

    test('back-to-back events do not conflict', () {
      final a = _event(DateTime(2026, 7, 17, 10), end: DateTime(2026, 7, 17, 11));
      final b = _event(DateTime(2026, 7, 17, 11), end: DateTime(2026, 7, 17, 12), id: 'e2');
      expect(a.overlaps(b), isFalse);
    });

    test('events without an end default to one hour', () {
      final a = _event(DateTime(2026, 7, 17, 10));
      final b = _event(DateTime(2026, 7, 17, 10, 45), id: 'e2');
      expect(a.overlaps(b), isTrue);
    });
  });
}
