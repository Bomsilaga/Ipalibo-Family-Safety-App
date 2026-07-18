import 'package:flutter_test/flutter_test.dart';
import 'package:ipalibos/features/ai_assistant/domain/quick_add_parser.dart';

void main() {
  // Friday 17 July 2026, 08:00 as the reference "now".
  final now = DateTime(2026, 7, 17, 8);

  group('parseQuickAdd', () {
    test('parses the spec example "Alex has swimming Tuesday 4pm"', () {
      final draft = parseQuickAdd('Alex has swimming Tuesday 4pm',
          now: now, knownNames: ['Alex', 'Sam']);
      expect(draft, isNotNull);
      expect(draft!.personName, 'Alex');
      expect(draft.title, 'Swimming');
      expect(draft.startAt.weekday, DateTime.tuesday);
      expect(draft.startAt.hour, 16);
      expect(draft.startAt.isAfter(now), isTrue);
    });

    test('tomorrow with 24h time', () {
      final draft = parseQuickAdd('dentist tomorrow 14:30', now: now);
      expect(draft!.startAt, DateTime(2026, 7, 18, 14, 30));
      expect(draft.title, 'Dentist');
    });

    test('defaults to 9am when no time given', () {
      final draft = parseQuickAdd('piano lesson Monday', now: now);
      expect(draft!.startAt.hour, 9);
      expect(draft.startAt.weekday, DateTime.monday);
    });

    test('empty and unparseable input returns null', () {
      expect(parseQuickAdd('', now: now), isNull);
      expect(parseQuickAdd('   ', now: now), isNull);
    });
  });
}
