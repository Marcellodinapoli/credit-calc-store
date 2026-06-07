// ================================================================
// IMPORT
// ================================================================
import 'package:flutter/material.dart';
import 'personal_form_shell.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/custom_tabbar_theme.dart';
import '../../core/theme/app_card_theme.dart';
import '../../core/dimensions.dart';
import 'course_details_page.dart' show CourseProgress, CourseDetailsPage;
import 'course_labels.dart';

// ================================================================
// PAGE ROOT
// ================================================================
class CrediFormProgressPage extends StatefulWidget {
  const CrediFormProgressPage({super.key});

  @override
  State<CrediFormProgressPage> createState() =>
      _CrediFormProgressPageState();
}

// ================================================================
// STATE
// ================================================================
class _CrediFormProgressPageState
    extends State<CrediFormProgressPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  List<CourseProgress> preDecadenza = [];
  List<CourseProgress> postDecadenza = [];
  bool _loading = true;

  // ================================================================
  // LIFECYCLE
  // ================================================================
  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadProgress();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // ================================================================
  // SERVICES
  // ================================================================
  CourseProgress _progressFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> d,
  ) {
    final data = d.data();
    final courseId = (data['courseId'] ?? d.id).toString();
    final courseLabel = (data['courseLabel'] ?? '').toString();

    return CourseProgress(
      title: (data['title'] ?? 'Corso senza titolo').toString(),
      code: courseLabel,
      courseId: courseId,
      videoViews: data['videoViews'] ?? 0,
      lastVideoDate: data['lastVideoDate']?.toDate(),
      quizAttempts: data['quizAttempts'] ?? 0,
      lastQuizDate: data['lastQuizDate']?.toDate(),
      lastScore: data['lastScore'],
      lastQuizTime: (data['lastQuizTime'] is int)
          ? Duration(seconds: data['lastQuizTime'])
          : data['lastQuizTime'],
      downloadCount: data['downloadCount'] ?? 0,
      downloadedFiles: List<String>.from(data['downloadedFiles'] ?? []),
      category: data['category'] ?? 'pre',
    );
  }

  /// Stesso ordine della pagina Corsi (createdAt ascendente) + etichetta Corso N.
  List<CourseProgress> _orderedProgressForCatalog(
    String catalogCategory,
    Map<String, CourseProgress> progressByCourseId,
    Map<String, Map<String, dynamic>> coursesById,
  ) {
    final catalogEntries = coursesById.entries
        .where((e) => (e.value['category'] ?? '').toString() == catalogCategory)
        .toList()
      ..sort((a, b) {
        final ta = a.value['createdAt'];
        final tb = b.value['createdAt'];
        final ma = ta is Timestamp ? ta.millisecondsSinceEpoch : 0;
        final mb = tb is Timestamp ? tb.millisecondsSinceEpoch : 0;
        return ma.compareTo(mb);
      });

    final ordered = <CourseProgress>[];
    final usedIds = <String>{};

    for (var i = 0; i < catalogEntries.length; i++) {
      final courseId = catalogEntries[i].key;
      final catalogData = catalogEntries[i].value;
      final progress = progressByCourseId[courseId];
      if (progress == null) continue;

      usedIds.add(courseId);
      ordered.add(
        progress.copyWith(
          courseId: courseId,
          title: (catalogData['title'] ?? progress.title).toString(),
          code: CourseLabels.label(category: catalogCategory, index: i),
          category: catalogCategory == CourseLabels.categorySollecito
              ? 'pre'
              : 'post',
        ),
      );
    }

    // Progressi senza corrispondenza nel catalogo (corsi rimossi, ecc.)
    for (final entry in progressByCourseId.entries) {
      if (usedIds.contains(entry.key)) continue;
      final legacyCategory = entry.value.category;
      final belongsHere = catalogCategory == CourseLabels.categorySollecito
          ? legacyCategory == 'pre'
          : legacyCategory == 'post';
      if (!belongsHere) continue;

      final catalogData = coursesById[entry.key];
      final title = catalogData != null
          ? (catalogData['title'] ?? entry.value.title).toString()
          : entry.value.title;

      final storedLabel = entry.value.code.trim();
      final label = storedLabel.isNotEmpty && storedLabel.startsWith('Corso')
          ? storedLabel
          : CourseLabels.label(
              category: catalogCategory,
              index: ordered.length,
            );

      ordered.add(
        entry.value.copyWith(
          courseId: entry.key,
          title: title,
          code: label,
        ),
      );
    }

    return ordered;
  }

  Future<void> _loadProgress() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _firestore
          .collection('userProgress')
          .doc(user.uid)
          .collection('courses')
          .get();

      final coursesSnap = await _firestore.collection('courses').get();
      final coursesById = {
        for (final d in coursesSnap.docs) d.id: d.data(),
      };

      final progressByCourseId = <String, CourseProgress>{};
      for (final d in snapshot.docs) {
        final progress = _progressFromDoc(d);
        final key =
            progress.courseId.isNotEmpty ? progress.courseId : d.id;
        progressByCourseId[key] = progress;
      }

      final pre = _orderedProgressForCatalog(
        CourseLabels.categorySollecito,
        progressByCourseId,
        coursesById,
      );
      final post = _orderedProgressForCatalog(
        CourseLabels.categoryRecupero,
        progressByCourseId,
        coursesById,
      );

      if (!mounted) return;
      setState(() {
        preDecadenza = pre;
        postDecadenza = post;
        _loading = false;
      });
    } catch (e) {
      debugPrint('❌ Errore caricamento progressi: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // ================================================================
  // CALCOLI
  // ================================================================
  double _calcProgress(int value) {
    return (value / 10).clamp(0, 1).toDouble();
  }

  // ================================================================
  // UI HELPERS
  // ================================================================
  Widget _progressRow(
      BuildContext context, String label, double value) {
    final percent = (value * 100).toStringAsFixed(0);
    final bool completed = value >= 1;

    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(label,
              style:
              const TextStyle(fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 10,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                completed ? Colors.blue : Colors.grey,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(width: 44, child: Text('$percent%')),
      ],
    );
  }

  Widget _coursesList(
      BuildContext context, List<CourseProgress> list) {
    if (list.isEmpty) {
      return const Center(
        child: Text(
          'Nessun progresso registrato.',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final c = list[i];

        final quizProgress = (c.lastScore != null)
            ? ((c.lastScore!.toDouble() / 100)
            .clamp(0.0, 1.0))
            : _calcProgress(c.quizAttempts);

        return Card(
          color: AppCardTheme.surface,
          elevation: AppCardTheme.elevation,
          shape: AppCardTheme.shape,
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  c.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  c.code,
                  style: const TextStyle(
                    color: Colors.blueGrey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                _progressRow(context, 'Video',
                    _calcProgress(c.videoViews)),
                const SizedBox(height: 8),
                _progressRow(context, 'Quiz',
                    quizProgress),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.download_done_outlined,
                        size: 18,
                        color: Colors.grey[700]),
                    const SizedBox(width: 6),
                    Text(
                        'File scaricati: ${c.downloadCount}'),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                CourseDetailsPage(
                                    course: c),
                          ),
                        );
                      },
                      icon:
                      const Icon(Icons.open_in_new),
                      label:
                      const Text('Dettagli'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ================================================================
  // BUILD
  // ================================================================
  @override
  Widget build(BuildContext context) {
    final isMobile = Dimensions.isTablet(context);
    final pad = Dimensions.pagePaddingFor(context);

    return PersonalFormShell(
      pageTitle: 'I miei progressi',
      body: Padding(
        padding: EdgeInsets.all(pad),
        child: Card(
          elevation: AppCardTheme.elevation,
          color: Colors.white,
          shape: AppCardTheme.shape,
          child: Padding(
            padding: EdgeInsets.all(pad),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Progresso corsi",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      CustomTabBarTheme.build(
                        context: context,
                        controller: _tab,
                        isScrollable: isMobile,
                        tabs: const [
                          Tab(text: 'Sollecito'),
                          Tab(text: 'Recupero'),
                        ],
                      ),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      Expanded(
                        child: TabBarView(
                          controller: _tab,
                          children: [
                            _coursesList(context, preDecadenza),
                            _coursesList(context, postDecadenza),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}