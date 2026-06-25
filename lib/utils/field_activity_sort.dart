import '../models/field_activity.dart';

List<FieldActivity> sortFieldActivities(List<FieldActivity> items) {
  final copy = List<FieldActivity>.from(items);
  copy.sort((a, b) {
    if (a.completed != b.completed) {
      return a.completed ? 1 : -1;
    }
    final dueA = a.dueAt ?? DateTime(2100);
    final dueB = b.dueAt ?? DateTime(2100);
    return dueA.compareTo(dueB);
  });
  return copy;
}
