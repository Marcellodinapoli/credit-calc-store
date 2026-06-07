// ================================================================
// IMPORT
// ================================================================
import 'package:flutter/material.dart';
import 'personal_form_shell.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/dimensions.dart';
import '../../core/theme/app_card_theme.dart';

// ================================================================
// PAGE ROOT
// ================================================================
class CourseDetailsPage extends StatelessWidget {
  final CourseProgress course;

  const CourseDetailsPage({super.key, required this.course});

  // ================================================================
  // BUILD
  // ================================================================
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final safeCourseId = course.courseId.isNotEmpty
        ? course.courseId
        : (course.code.isNotEmpty ? course.code : course.title);

    return PersonalFormShell(
      pageTitle: course.title,
      body: Column(
        children: [

          // ----------------------------------------------------------
          // NAVIGAZIONE PRECEDENTE / SUCCESSIVO
          // ----------------------------------------------------------
          if (user != null)
            FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('userProgress')
                  .doc(user.uid)
                  .collection('courses')
                  .orderBy('title')
                  .get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final docs = snapshot.data!.docs;
                if (docs.length < 2) {
                  return const SizedBox.shrink();
                }

                final index = docs.indexWhere((d) =>
                (d['courseId'] ?? d['title']) == safeCourseId);

                if (index == -1) {
                  return const SizedBox.shrink();
                }

                final prev = index > 0
                    ? docs[index - 1].data() as Map<String, dynamic>
                    : null;

                final next = index < docs.length - 1
                    ? docs[index + 1].data() as Map<String, dynamic>
                    : null;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (prev != null)
                        TextButton.icon(
                          icon: const Icon(Icons.arrow_back),
                          label: Text(prev['title'] ?? 'Precedente'),
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CourseDetailsPage(
                                  course: CourseProgress(
                                    title: (prev['title'] ?? '').toString(),
                                    code: (prev['courseLabel'] ??
                                            prev['courseId'] ??
                                            '')
                                        .toString(),
                                    courseId:
                                        (prev['courseId'] ?? '').toString(),
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      else
                        const SizedBox(width: 120),

                      if (next != null)
                        TextButton.icon(
                          icon: const Icon(Icons.arrow_forward),
                          label: Text(next['title'] ?? 'Successivo'),
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CourseDetailsPage(
                                  course: CourseProgress(
                                    title: (next['title'] ?? '').toString(),
                                    code: (next['courseLabel'] ??
                                            next['courseId'] ??
                                            '')
                                        .toString(),
                                    courseId:
                                        (next['courseId'] ?? '').toString(),
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      else
                        const SizedBox(width: 120),
                    ],
                  ),
                );
              },
            ),

          // ----------------------------------------------------------
          // CONTENUTO PRINCIPALE
          // ----------------------------------------------------------
          Expanded(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: Dimensions.scrollPadding(context),
              children: [

                // ================= VIDEO =================
                _infoCard(
                  context,
                  title: "Video",
                  children: [
                    _kv("Numero visualizzazioni", "${course.videoViews}"),
                    _kv(
                      "Ultima visualizzazione",
                      course.lastVideoDate != null
                          ? _fmtDate(course.lastVideoDate!)
                          : "—",
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ================= QUIZ =================
                if (user != null)
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('userProgress')
                        .doc(user.uid)
                        .collection('courses')
                        .doc(safeCourseId)
                        .get(),
                    builder: (context, snap) {
                      int correct = 0;
                      int wrong = 0;

                      if (snap.hasData && snap.data!.exists) {
                        final data =
                        snap.data!.data() as Map<String, dynamic>?;

                        if (data != null &&
                            data.containsKey('answerDetails')) {
                          final list =
                          List<Map<String, dynamic>>.from(
                              data['answerDetails']);

                          correct = list
                              .where((e) =>
                          e['isCorrect'] == true)
                              .length;

                          wrong = list
                              .where((e) =>
                          e['isCorrect'] == false)
                              .length;
                        }
                      }

                      return _infoCard(
                        context,
                        title: "Quiz",
                        children: [
                          _kv("Numero tentativi",
                              "${course.quizAttempts}"),
                          _kv(
                            "Ultima esecuzione",
                            course.lastQuizDate != null
                                ? _fmtDate(course.lastQuizDate!)
                                : "—",
                          ),
                          _kv(
                            "Ultimo punteggio",
                            course.lastScore != null
                                ? "${course.lastScore}%"
                                : "—",
                          ),
                          _kv(
                            "Tempo ultimo tentativo",
                            course.lastQuizTime != null
                                ? "${course.lastQuizTime!.inMinutes} min "
                                "${course.lastQuizTime!.inSeconds % 60} sec"
                                : "—",
                          ),
                          _kv("Risposte corrette",
                              correct > 0 ? "$correct" : "—"),
                          _kv("Risposte errate",
                              wrong > 0 ? "$wrong" : "—"),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () {
                              _showAnswersDialog(context, safeCourseId);
                            },
                            icon: const Icon(
                                Icons.visibility_outlined),
                            label: const Text(
                                "Dettaglio risposte"),
                          ),
                        ],
                      );
                    },
                  ),

                const SizedBox(height: 16),

                // ================= FILE =================
                _infoCard(
                  context,
                  title: "File scaricati",
                  children: [
                    _kv("Totale",
                        "${course.downloadCount}"),
                    ...course.downloadedFiles.map(
                          (f) => Row(
                        children: [
                          const Icon(
                              Icons.file_download_outlined,
                              size: 18,
                              color: Colors.blueGrey),
                          const SizedBox(width: 6),
                          Expanded(child: Text(f)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // UI HELPERS
  // ================================================================
  Widget _infoCard(BuildContext context,
      {required String title,
        required List<Widget> children}) {
    return Card(
      color: AppCardTheme.surface,
      elevation: AppCardTheme.elevation,
      shape: AppCardTheme.shape,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ...children,
            ]),
      ),
    );
  }

  static Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        SizedBox(
          width: 200,
          child: Text(k,
              style: const TextStyle(
                  fontWeight: FontWeight.w600)),
        ),
        Expanded(child: Text(v)),
      ],
    ),
  );

  String _fmtDate(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}/"
          "${d.month.toString().padLeft(2, '0')}/"
          "${d.year} "
          "${d.hour.toString().padLeft(2, '0')}:"
          "${d.minute.toString().padLeft(2, '0')}";

  // ================================================================
  // ACTIONS
  // ================================================================
  List<Map<String, dynamic>> _detailsFromData(
    Map<String, dynamic>? data,
  ) {
    if (data == null || !data.containsKey('answerDetails')) {
      return [];
    }
    return List<Map<String, dynamic>>.from(data['answerDetails']);
  }

  Future<List<Map<String, dynamic>>> _loadAnswerDetails(
    String uid,
    String safeCourseId,
  ) async {
    final col = FirebaseFirestore.instance
        .collection('userProgress')
        .doc(uid)
        .collection('courses');

    final doc = await col.doc(safeCourseId).get();
    if (doc.exists) {
      final details = _detailsFromData(doc.data());
      if (details.isNotEmpty) return details;
    }

    var query = await col
        .where('courseId', isEqualTo: safeCourseId)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      final details = _detailsFromData(query.docs.first.data());
      if (details.isNotEmpty) return details;
    }

    if (course.title.isNotEmpty) {
      query = await col
          .where('title', isEqualTo: course.title)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        return _detailsFromData(query.docs.first.data());
      }
    }

    return [];
  }

  static Widget _answerDetailRow({
    required String question,
    required String selected,
    required bool isCorrect,
  }) {
    final iconColor = isCorrect ? Colors.green : Colors.red;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  question,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                color: iconColor,
                size: 22,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Risposta data: $selected',
            style: TextStyle(color: Colors.grey.shade800),
          ),
          const Divider(height: 20),
        ],
      ),
    );
  }

  void _showAnswersDialog(
      BuildContext context, String safeCourseId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    List<Map<String, dynamic>> details = [];

    try {
      details = await _loadAnswerDetails(user.uid, safeCourseId);
    } catch (_) {}

    if (!context.mounted) return;

    final isPhone = Dimensions.isPhone(context);
    final screenH = MediaQuery.sizeOf(context).height;
    final dialogW = Dimensions.dialogWidth(context);
    final contentH =
        (screenH * (isPhone ? 0.52 : 0.48)).clamp(220.0, 430.0);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: isPhone ? 12 : 24,
          vertical: isPhone ? 20 : 16,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Dettaglio risposte quiz',
              style: TextStyle(
                fontSize: isPhone ? 18 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (course.title.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                course.title,
                style: TextStyle(
                  fontSize: isPhone ? 15 : 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (course.code.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                course.code,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.blueGrey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        content: SizedBox(
          width: dialogW,
          height: contentH,
          child: details.isEmpty
              ? const Center(
                  child: Text('Nessun dettaglio disponibile'),
                )
              : ListView.builder(
                  itemCount: details.length,
                  itemBuilder: (context, i) {
                    final d = details[i];
                    return _answerDetailRow(
                      question: d['question'] ?? 'Domanda ${i + 1}',
                      selected: d['selected'] ?? '—',
                      isCorrect: d['isCorrect'] ?? false,
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(
              dialogContext,
              rootNavigator: true,
            ).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// MODEL
// ================================================================
class CourseProgress {
  final String title;
  final String code;
  final String courseId;
  final int videoViews;
  final DateTime? lastVideoDate;
  final int quizAttempts;
  final DateTime? lastQuizDate;
  final int? lastScore;
  final Duration? lastQuizTime;
  final int? quizCorrectPercent;
  final int downloadCount;
  final List<String> downloadedFiles;
  final String category;

  const CourseProgress({
    required this.title,
    required this.code,
    this.courseId = '',
    this.videoViews = 0,
    this.lastVideoDate,
    this.quizAttempts = 0,
    this.lastQuizDate,
    this.lastScore,
    this.lastQuizTime,
    this.quizCorrectPercent,
    this.downloadCount = 0,
    this.downloadedFiles = const [],
    this.category = 'pre',
  });

  CourseProgress copyWith({
    String? title,
    String? code,
    String? courseId,
    int? videoViews,
    DateTime? lastVideoDate,
    int? quizAttempts,
    DateTime? lastQuizDate,
    int? lastScore,
    Duration? lastQuizTime,
    int? quizCorrectPercent,
    int? downloadCount,
    List<String>? downloadedFiles,
    String? category,
  }) {
    return CourseProgress(
      title: title ?? this.title,
      code: code ?? this.code,
      courseId: courseId ?? this.courseId,
      videoViews: videoViews ?? this.videoViews,
      lastVideoDate:
      lastVideoDate ?? this.lastVideoDate,
      quizAttempts:
      quizAttempts ?? this.quizAttempts,
      lastQuizDate:
      lastQuizDate ?? this.lastQuizDate,
      lastScore: lastScore ?? this.lastScore,
      lastQuizTime:
      lastQuizTime ?? this.lastQuizTime,
      quizCorrectPercent:
      quizCorrectPercent ??
          this.quizCorrectPercent,
      downloadCount:
      downloadCount ?? this.downloadCount,
      downloadedFiles:
      downloadedFiles ??
          this.downloadedFiles,
      category: category ?? this.category,
    );
  }
}