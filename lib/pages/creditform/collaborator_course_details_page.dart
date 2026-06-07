import 'package:flutter/material.dart';
import 'personal_form_shell.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/dimensions.dart';
import '../../core/theme/app_card_theme.dart';

// -----------------------------------------------------------------------------
// PAGE
// -----------------------------------------------------------------------------
class CollaboratorCourseDetailsPage extends StatelessWidget {
  final String collaboratorUserId;
  final CourseProgress course;

  const CollaboratorCourseDetailsPage({
    super.key,
    required this.collaboratorUserId,
    required this.course,
  });

// -----------------------------------------------------------------------------
// BUILD
// -----------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return PersonalFormShell(
      pageTitle: course.title,
      body: Column(
        children: [

          // -------------------------------------------------------------------
          // NAVIGAZIONE PRECEDENTE / SUCCESSIVO
          // -------------------------------------------------------------------
          FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('userProgress')
                .doc(collaboratorUserId)
                .collection('courses')
                .orderBy('title')
                .get(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();

              final docs = snapshot.data!.docs;
              if (docs.length < 2) return const SizedBox.shrink();

              final index = docs.indexWhere((d) =>
              (d['courseId'] ?? d['title']) ==
                  (course.code.isNotEmpty ? course.code : course.title));

              final prev =
              index > 0 ? docs[index - 1].data() as Map<String, dynamic> : null;
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
                              builder: (_) => CollaboratorCourseDetailsPage(
                                collaboratorUserId: collaboratorUserId,
                                course: CourseProgress(
                                  title: prev['title'],
                                  code: prev['courseId'] ?? '',
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
                              builder: (_) => CollaboratorCourseDetailsPage(
                                collaboratorUserId: collaboratorUserId,
                                course: CourseProgress(
                                  title: next['title'],
                                  code: next['courseId'] ?? '',
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

          // -------------------------------------------------------------------
          // CONTENUTO
          // -------------------------------------------------------------------
          Expanded(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: Dimensions.scrollPadding(context),
              children: [

                // ----------------------- VIDEO -----------------------
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

                // ----------------------- QUIZ -----------------------
                FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('userProgress')
                      .doc(collaboratorUserId)
                      .collection('courses')
                      .get(),
                  builder: (context, snap) {
                    int correct = 0;
                    int wrong = 0;

                    int quizAttempts = course.quizAttempts;
                    DateTime? lastQuizDate = course.lastQuizDate;
                    int? lastScore = course.lastScore;
                    Duration? lastQuizTime = course.lastQuizTime;

                    if (snap.hasData && snap.data!.docs.isNotEmpty) {
                      QueryDocumentSnapshot? match;

                      for (final d in snap.data!.docs) {
                        if (d['courseId'] == course.code ||
                            d['title'] == course.title) {
                          match = d;
                          break;
                        }
                      }

                      match ??= snap.data!.docs.first;

                      final data = match.data() as Map<String, dynamic>;

                      if (data.containsKey('answerDetails')) {
                        final list =
                        List<Map<String, dynamic>>.from(data['answerDetails']);
                        correct =
                            list.where((e) => e['isCorrect'] == true).length;
                        wrong =
                            list.where((e) => e['isCorrect'] == false).length;
                      }

                      quizAttempts = data['quizAttempts'] ?? quizAttempts;
                      lastScore = data['lastScore'] ?? lastScore;
                      lastQuizDate =
                          (data['lastQuizDate'] as Timestamp?)?.toDate() ??
                              lastQuizDate;

                      if (data['timeLastAttempt'] != null) {
                        lastQuizTime =
                            Duration(seconds: data['timeLastAttempt']);
                      }
                    }

                    return _infoCard(
                      context,
                      title: "Quiz",
                      children: [
                        _kv("Numero tentativi", "$quizAttempts"),
                        _kv(
                          "Ultima esecuzione",
                          lastQuizDate != null
                              ? _fmtDate(lastQuizDate)
                              : "—",
                        ),
                        _kv(
                          "Ultimo punteggio",
                          lastScore != null ? "$lastScore%" : "—",
                        ),
                        _kv(
                          "Tempo ultimo tentativo",
                          lastQuizTime != null
                              ? "${lastQuizTime.inMinutes} min ${lastQuizTime.inSeconds % 60} sec"
                              : "—",
                        ),
                        _kv("Risposte corrette",
                            correct > 0 ? "$correct" : "—"),
                        _kv("Risposte errate",
                            wrong > 0 ? "$wrong" : "—"),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () {
                            _showAnswersDialog(context);
                          },
                          icon: const Icon(Icons.visibility_outlined),
                          label: const Text("Dettaglio risposte"),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 16),

                // ----------------------- FILE -----------------------
                _infoCard(
                  context,
                  title: "File scaricati",
                  children: [
                    _kv("Totale", "${course.downloadCount}"),
                    ...course.downloadedFiles.map(
                          (f) => Row(
                        children: [
                          const Icon(Icons.file_download_outlined,
                              size: 18, color: Colors.blueGrey),
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

// -----------------------------------------------------------------------------
// UI HELPERS
// -----------------------------------------------------------------------------
  Widget _infoCard(BuildContext context,
      {required String title, required List<Widget> children}) {
    return Card(
      color: AppCardTheme.surface,
      elevation: AppCardTheme.elevation,
      shape: AppCardTheme.shape,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
              const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        Expanded(child: Text(v)),
      ],
    ),
  );

  String _fmtDate(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} "
          "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";

// -----------------------------------------------------------------------------
// ACTIONS
// -----------------------------------------------------------------------------
  void _showAnswersDialog(BuildContext context) async {
    List<Map<String, dynamic>> details = [];

    try {
      final query = await FirebaseFirestore.instance
          .collection('userProgress')
          .doc(collaboratorUserId)
          .collection('courses')
          .where(
        'courseId',
        isEqualTo:
        course.code.trim().isNotEmpty ? course.code.trim() : null,
      )
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        if (data.containsKey('answerDetails')) {
          details = List<Map<String, dynamic>>.from(data['answerDetails']);
        }
      }
    } catch (_) {}

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Dettaglio risposte quiz"),
        content: SizedBox(
          width: 520,
          height: 430,
          child: details.isEmpty
              ? const Center(child: Text("Nessun dettaglio disponibile"))
              : ListView.builder(
            itemCount: details.length,
            itemBuilder: (context, i) {
              final d = details[i];
              final question = d['question'] ?? "Domanda ${i + 1}";
              final selected = d['selected'] ?? "—";
              final isCorrect = d['isCorrect'] ?? false;

              return ListTile(
                title: Text(question),
                subtitle: Text("Risposta data: $selected"),
                trailing: Icon(
                  isCorrect ? Icons.check_circle : Icons.cancel,
                  color: isCorrect ? Colors.green : Colors.red,
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context, rootNavigator: true).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// MODEL
// -----------------------------------------------------------------------------
class CourseProgress {
  final String title;
  final String code;
  final int videoViews;
  final DateTime? lastVideoDate;
  final int quizAttempts;
  final DateTime? lastQuizDate;
  final int? lastScore;
  final Duration? lastQuizTime;
  final int downloadCount;
  final List<String> downloadedFiles;
  final String category;

  const CourseProgress({
    required this.title,
    required this.code,
    this.videoViews = 0,
    this.lastVideoDate,
    this.quizAttempts = 0,
    this.lastQuizDate,
    this.lastScore,
    this.lastQuizTime,
    this.downloadCount = 0,
    this.downloadedFiles = const [],
    this.category = 'pre',
  });

  CourseProgress copyWith({
    String? title,
    String? code,
    int? videoViews,
    DateTime? lastVideoDate,
    int? quizAttempts,
    DateTime? lastQuizDate,
    int? lastScore,
    Duration? lastQuizTime,
    int? downloadCount,
    List<String>? downloadedFiles,
    String? category,
  }) {
    return CourseProgress(
      title: title ?? this.title,
      code: code ?? this.code,
      videoViews: videoViews ?? this.videoViews,
      lastVideoDate: lastVideoDate ?? this.lastVideoDate,
      quizAttempts: quizAttempts ?? this.quizAttempts,
      lastQuizDate: lastQuizDate ?? this.lastQuizDate,
      lastScore: lastScore ?? this.lastScore,
      lastQuizTime: lastQuizTime ?? this.lastQuizTime,
      downloadCount: downloadCount ?? this.downloadCount,
      downloadedFiles: downloadedFiles ?? this.downloadedFiles,
      category: category ?? this.category,
    );
  }
}
