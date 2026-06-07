// ignore_for_file: deprecated_member_use
// ---------------------------------------------------------------------------
// IMPORT
// ---------------------------------------------------------------------------
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'personal_form_shell.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'training_page.dart';
import '../../core/theme/custom_tabbar_theme.dart';
import '../../core/theme/app_card_theme.dart';
import '../../core/dimensions.dart';
import 'course_labels.dart';
import 'package:url_launcher/url_launcher.dart';


// ---------------------------------------------------------------------------
// WIDGET PUBBLICI
// ---------------------------------------------------------------------------
class CoursesPage extends StatefulWidget {
  const CoursesPage({super.key});

  @override
  State<CoursesPage> createState() => _CoursesPageState();
}


// ---------------------------------------------------------------------------
// STATE
// ---------------------------------------------------------------------------
class _CoursesPageState extends State<CoursesPage>
    with SingleTickerProviderStateMixin {

  late TabController _tab;

  // ---------------------------------------------------------------------------
  // LIFECYCLE
  // ---------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return PersonalFormShell(
      pageTitle: 'Corsi',
      body: Column(
        children: [
          const SizedBox(height: 8),
          CustomTabBarTheme.build(
            context: context,
            controller: _tab,
            isScrollable: true,
            tabs: const [
              Tab(text: 'Sollecito'),
              Tab(text: 'Recupero'),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tab,
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                _CoursesBody(preDecadenza: true),
                _CoursesBody(preDecadenza: false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// UI PRIVATE
// ---------------------------------------------------------------------------
class _CoursesBody extends StatelessWidget {
  final bool preDecadenza;
  const _CoursesBody({required this.preDecadenza});

  static const String categorySollecito = "Sollecito";
  static const String categoryRecupero = "Recupero";

  @override
  Widget build(BuildContext context) {

    final category =
    preDecadenza ? categorySollecito : categoryRecupero;

    final isMobile = Dimensions.isTablet(context);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('courses')
          .where('category', isEqualTo: category)
          .orderBy('createdAt', descending: false)
          .withConverter<Map<String, dynamic>>(
        fromFirestore: (snap, _) => snap.data() ?? {},
        toFirestore: (data, _) => data,
      ).snapshots(),
      builder: (context, snapshot) {

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              "❌ Errore nel caricamento corsi\n${snapshot.error}",
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Text("Nessun corso disponibile",
                style: TextStyle(color: Colors.black54)),
          );
        }

        final int totalCourses = docs.length;
        final String totalDuration = "—";

        final screenW = MediaQuery.sizeOf(context).width;
        final horizontalPad = Dimensions.pagePaddingFor(context) * 2;
        final double cardWidth = isMobile
            ? (screenW - horizontalPad - 16).clamp(280.0, screenW)
            : 380;
        final double cardHeight = isMobile ? 480 : 520;

        final platform = Theme.of(context).platform;
        final ScrollPhysics pagePhysics =
            platform == TargetPlatform.iOS || platform == TargetPlatform.macOS
                ? const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  )
                : const ClampingScrollPhysics();

        return ScrollConfiguration(
          behavior: const MaterialScrollBehavior().copyWith(
            overscroll: false,
          ),
          child: SingleChildScrollView(
            physics: pagePhysics,
            dragStartBehavior: DragStartBehavior.down,
            padding: Dimensions.scrollPadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Text(
                          "$totalCourses corsi",
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          "Durata totale: $totalDuration",
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment:
                        isMobile ? WrapAlignment.start : WrapAlignment.center,
                    children: docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final id = doc.id;
                      final title = data['title']?.toString() ?? '—';
                      final desc = data['description']?.toString() ?? '';

                      // 🔧 Normalizzazione sicura
                      final rawTags = data['tags'];
                      final String tags = rawTags is List
                          ? rawTags.map((e) => e.toString()).join(', ')
                          : 'Nessun tag';

                      final rawContents = data['contents'];
                      final List contents = rawContents is List
                          ? rawContents.map((e) => e.toString()).toList()
                          : [];

                      final rawAttachments = data['attachments'];
                      final List attachments = rawAttachments is List
                          ? rawAttachments
                          : [];

                      final code = CourseLabels.label(
                        category: category,
                        index: docs.indexOf(doc),
                      );

                      return _CourseCard(
                        id: id,
                        title: title,
                        code: code,
                        catalogCategory: category,
                        description: desc,
                        tags: tags,
                        contents: contents,
                        attachments: attachments,
                        width: cardWidth,
                        height: cardHeight,
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}


// ---------------------------------------------------------------------------
// COMPONENTI
// ---------------------------------------------------------------------------
class _CourseCard extends StatelessWidget {

  final String id;
  final String title;
  final String code;
  final String catalogCategory;
  final String description;
  final String tags;
  final List contents;
  final List attachments;
  final double width;
  final double height;

  const _CourseCard({
    required this.id,
    required this.title,
    required this.code,
    required this.catalogCategory,
    required this.description,
    required this.tags,
    required this.contents,
    required this.attachments,
    required this.width,
    required this.height,
  });

  String _extractFileName(String url) {
    try {
      final decoded = Uri.decodeFull(url);
      String name = decoded.split('/').last;
      name = name.split('?').first;
      name = name.replaceAll(RegExp(r'^attachments%2F'), '');
      name = name.replaceAll(RegExp(r'^[0-9]+_'), '');
      name = Uri.decodeComponent(name);
      return name;
    } catch (_) {
      return url;
    }
  }

  @override
  Widget build(BuildContext context) {
    const pink = Color(0xFFE91E63);

    return SizedBox(
      width: width,
      height: height,
      child: Card(
        elevation: AppCardTheme.elevation,
        color: AppCardTheme.surface,
        shape: AppCardTheme.shape,
        child: Padding(
          padding:
          const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFA726),
                  borderRadius:
                  BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    code,
                    style: const TextStyle(
                      color: Colors.blueGrey,
                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  const _StatusPill(
                      text: 'Non iniziato',
                      color: pink),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  primary: false,
                  physics: const ClampingScrollPhysics(),
                  dragStartBehavior: DragStartBehavior.down,
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      const Text('Cosa contiene:',
                          style: TextStyle(
                              fontWeight:
                              FontWeight.w700)),
                      const SizedBox(height: 6),
                      if (contents.isNotEmpty)
                        ...contents
                            .map((item) =>
                            Text('• $item'))
                            
                      else
                        const Text('—'),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text('Cosa vedremo:',
                            style: TextStyle(
                                fontWeight:
                                FontWeight.w700)),
                        Row(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            const Text('• '),
                            Expanded(
                              child: Text(
                                description,
                                maxLines: 3,
                                overflow:
                                TextOverflow
                                    .ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (attachments.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text('Allegati:',
                            style: TextStyle(
                                fontWeight:
                                FontWeight.w700)),
                        ...attachments.map((file) {
                          String url = '';
                          String name = '';
                          if (file is String) {
                            url = file;
                            name =
                                _extractFileName(url);
                          } else if (file is Map) {
                            url =
                                file['url'] ?? '';
                            name = file['name'] ??
                                (url.isNotEmpty
                                    ? _extractFileName(
                                    url)
                                    : 'file');
                          }
                          return InkWell(
                            onTap: () async {
                              if (url.isNotEmpty &&
                                  await canLaunchUrl(
                                      Uri.parse(
                                          url))) {
                                await launchUrl(
                                  Uri.parse(url),
                                  mode: LaunchMode
                                      .externalApplication,
                                );
                              }
                            },
                            child: Padding(
                              padding:
                              const EdgeInsets
                                  .symmetric(
                                  vertical: 2.0),
                              child: Text(
                                '📎 $name',
                                style: const TextStyle(
                                    color: Colors
                                        .blueAccent),
                              ),
                            ),
                          );
                        }),
                      ],
                      if (tags.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text('Tag:',
                            style: TextStyle(
                                fontWeight:
                                FontWeight.w700)),
                        Text(tags,
                            maxLines: 2,
                            overflow:
                            TextOverflow
                                .ellipsis),
                      ],
                    ],
                  ),
                ),
              ),
              Align(
                alignment:
                Alignment.bottomRight,
                child: OutlinedButton(
                  style: OutlinedButton
                      .styleFrom(
                    side: const BorderSide(
                        color: pink,
                        width: 2),
                    foregroundColor: pink,
                    shape:
                    const StadiumBorder(),
                    padding:
                    const EdgeInsets
                        .symmetric(
                        horizontal: 22,
                        vertical: 10),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            TrainingPage(
                              courseTitle: title,
                              courseId: id,
                              courseLabel: code,
                              catalogCategory: catalogCategory,
                            ),
                      ),
                    );
                  },
                  child:
                  const Text('Accedi'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {

  final String text;
  final Color color;

  const _StatusPill({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(
            color: color,
            width: 2),
        borderRadius:
        BorderRadius.circular(16),
        color: Colors.white,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight:
          FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}