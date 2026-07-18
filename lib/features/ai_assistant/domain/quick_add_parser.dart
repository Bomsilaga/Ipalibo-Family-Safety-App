/// Natural-language quick-add (product spec §16): "Alex has swimming
/// Tuesday 4pm" → a draft event for confirmation. Deliberately a local,
/// deterministic parser — no text leaves the family's account scope, and
/// the result is ALWAYS a draft the user confirms, never an auto-save.
class QuickAddDraft {
  const QuickAddDraft({required this.title, this.personName, required this.startAt});

  final String title;
  final String? personName;
  final DateTime startAt;
}

QuickAddDraft? parseQuickAdd(String input, {DateTime? now, List<String> knownNames = const []}) {
  final reference = now ?? DateTime.now();
  var text = input.trim();
  if (text.isEmpty) return null;

  // Person: a known family member's name appearing before "has/have".
  String? person;
  final hasMatch = RegExp(r'^(\w+)\s+has\s+', caseSensitive: false).firstMatch(text);
  if (hasMatch != null) {
    final candidate = hasMatch.group(1)!;
    person = knownNames.firstWhere(
      (n) => n.toLowerCase() == candidate.toLowerCase(),
      orElse: () => candidate,
    );
    text = text.substring(hasMatch.end);
  }

  // Time: "4pm", "16:30", "at 7".
  var hour = 9;
  var minute = 0;
  final timeMatch = RegExp(r'\b(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b', caseSensitive: false)
      .firstMatch(text);
  String timeText = '';
  if (timeMatch != null) {
    hour = int.parse(timeMatch.group(1)!);
    minute = timeMatch.group(2) != null ? int.parse(timeMatch.group(2)!) : 0;
    final meridiem = timeMatch.group(3)?.toLowerCase();
    if (meridiem == 'pm' && hour < 12) hour += 12;
    if (meridiem == 'am' && hour == 12) hour = 0;
    if (hour > 23 || minute > 59) return null;
    timeText = timeMatch.group(0)!;
  }

  // Day: weekday name, "today", "tomorrow".
  var date = reference;
  final dayNames = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
  String dayText = '';
  final lower = text.toLowerCase();
  if (lower.contains('tomorrow')) {
    date = reference.add(const Duration(days: 1));
    dayText = 'tomorrow';
  } else {
    for (var i = 0; i < dayNames.length; i++) {
      if (lower.contains(dayNames[i])) {
        var delta = (i + 1 - reference.weekday) % 7;
        if (delta <= 0) delta += 7; // "Tuesday" always means the next one
        date = reference.add(Duration(days: delta));
        dayText = dayNames[i];
        break;
      }
    }
  }

  // Title: whatever's left after stripping the recognised fragments.
  var title = text;
  if (timeText.isNotEmpty) title = title.replaceFirst(RegExp(RegExp.escape(timeText), caseSensitive: false), '');
  if (dayText.isNotEmpty) title = title.replaceFirst(RegExp(dayText, caseSensitive: false), '');
  title = title.replaceAll(RegExp(r'\s+'), ' ').replaceAll(RegExp(r'\s*(on|at)\s*$'), '').trim();
  if (title.isEmpty) return null;
  title = title[0].toUpperCase() + title.substring(1);

  return QuickAddDraft(
    title: title,
    personName: person,
    startAt: DateTime(date.year, date.month, date.day, hour, minute),
  );
}
