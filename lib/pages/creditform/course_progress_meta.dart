import 'package:cloud_firestore/cloud_firestore.dart';

import 'course_labels.dart';

/// Metadati corso scritti su ogni documento in userProgress/courses.
abstract final class CourseProgressMeta {
  static DocumentReference<Map<String, dynamic>> docRef(
    String uid,
    String courseId,
  ) {
    return FirebaseFirestore.instance
        .collection('userProgress')
        .doc(uid)
        .collection('courses')
        .doc(courseId);
  }

  static String storageCategory(String catalogCategory) {
    return CourseLabels.isRecuperoCategory(catalogCategory) ? 'post' : 'pre';
  }

  static Map<String, dynamic> fields({
    required String courseId,
    required String title,
    required String courseLabel,
    String? catalogCategory,
  }) {
    return {
      'courseId': courseId,
      'title': title,
      'courseLabel': courseLabel,
      if (catalogCategory != null && catalogCategory.isNotEmpty)
        'category': storageCategory(catalogCategory),
    };
  }
}
