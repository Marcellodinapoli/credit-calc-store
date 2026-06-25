import 'develop_local_collection.dart';

class DevelopLocalRecord {
  const DevelopLocalRecord({
    required this.id,
    required this.collection,
    required this.userId,
    required this.payload,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final DevelopLocalCollection collection;
  final String userId;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final DateTime updatedAt;
}
