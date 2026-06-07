// ignore_for_file: deprecated_member_use
// -----------------------------------------------------------------------------
// IMPORT / CONFIG
// -----------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'personal_form_shell.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/app_card_theme.dart';
import 'quiz_tab.dart';
import 'course_progress_meta.dart';

// -----------------------------------------------------------------------------
// PAGE ROOT + PROPS
// -----------------------------------------------------------------------------
class TrainingPage extends StatefulWidget {
  final String courseTitle;
  final String courseId;
  final String courseLabel;
  final String? catalogCategory;
  final String? previousTitle;
  final String? nextTitle;
  final VoidCallback? onPreviousCourse;
  final VoidCallback? onNextCourse;
  final String? videoUrl;

  // 🔽 navigazione corsi
  final int? courseIndex;
  final int? totalCourses;

  const TrainingPage({
    super.key,
    required this.courseTitle,
    required this.courseId,
    required this.courseLabel,
    this.catalogCategory,
    this.previousTitle,
    this.nextTitle,
    this.onPreviousCourse,
    this.onNextCourse,
    this.videoUrl,
    this.courseIndex,
    this.totalCourses,
  });

  @override
  State<TrainingPage> createState() => _TrainingPageState();
}

// -----------------------------------------------------------------------------
// STATE + LIFECYCLE
// -----------------------------------------------------------------------------
class _TrainingPageState extends State<TrainingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const Color brandAccent = Color(0xFF1565C0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

// -----------------------------------------------------------------------------
// UI HELPERS
// -----------------------------------------------------------------------------
  Widget _contentWidth(
      Widget child, {
        EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 16),
      }) =>
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1300),
          child: Padding(padding: padding, child: child),
        ),
      );

  void _fallbackSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigazione non configurata')),
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD — TRAINING PAGE
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return PersonalFormShell(
      pageTitle: 'Training',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Center(
              child: Text(
                widget.courseTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
          _contentWidth(
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (widget.previousTitle != null)
                    _NavButton(
                      alignment: NavAlignment.left,
                      label: 'PRECEDENTE',
                      title: widget.previousTitle!,
                      enabled: widget.onPreviousCourse != null,
                      onTap: widget.onPreviousCourse ?? _fallbackSnack,
                    )
                  else
                    const SizedBox(width: 100),
                  if (widget.nextTitle != null)
                    _NavButton(
                      alignment: NavAlignment.right,
                      label: 'SUCCESSIVO',
                      title: widget.nextTitle!,
                      enabled: widget.onNextCourse != null,
                      onTap: widget.onNextCourse ?? _fallbackSnack,
                    )
                  else
                    const SizedBox(width: 100),
                ],
              ),
            ),
          ),
          _contentWidth(
            TabBar(
              controller: _tabController,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.black54,
              indicatorColor: brandAccent,
              tabs: const [
                Tab(text: 'Video corso'),
                Tab(text: 'Quiz'),
                Tab(text: 'Allegati'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildVideoTab(),
                QuizTab(
                  courseId: widget.courseId,
                  courseTitle: widget.courseTitle,
                  courseLabel: widget.courseLabel,
                  catalogCategory: widget.catalogCategory,
                ),
                _buildAttachmentsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

// -----------------------------------------------------------------------------
// VIDEO TAB
// -----------------------------------------------------------------------------
  Widget _buildVideoTab() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text('Contenuto video non disponibile'));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final String? videoUrl = widget.videoUrl ?? data['videoUrl'];

        if (videoUrl == null || videoUrl.isEmpty) {
          return const Center(child: Text('Contenuto video non disponibile'));
        }

        if (videoUrl.startsWith('http')) {
          final controller = WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..loadRequest(Uri.parse(videoUrl));

          return AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(
              color: Colors.black,
              child: WebViewWidget(controller: controller),
            ),
          );
        }

        return const Center(child: Text('Formato video non supportato'));
      },
    );
  }

// -----------------------------------------------------------------------------
// ATTACHMENTS — HELPERS
// -----------------------------------------------------------------------------
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

// -----------------------------------------------------------------------------
// ATTACHMENTS TAB
// -----------------------------------------------------------------------------
  Widget _buildAttachmentsTab() {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text('❌ Corso non trovato'));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final attachmentsRaw = (data?['attachments'] as List?) ?? [];

        final attachments = attachmentsRaw
            .whereType<Map<String, dynamic>>()
            .toList();

        if (attachments.isEmpty) {
          return const Center(
            child: Text(
              '⚠️ Nessun allegato disponibile per questo corso',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return FutureBuilder<DocumentSnapshot>(
          future: user == null
              ? null
              : FirebaseFirestore.instance
              .collection('userProgress')
              .doc(user.uid)
              .collection('courses')
              .doc(widget.courseId)
              .get(),
          builder: (context, progressSnap) {
            final downloaded =
                (progressSnap.data?.data() as Map<String, dynamic>?)
                ?['downloadedFiles'] ??
                    [];

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: attachments.length,
              itemBuilder: (context, index) {
                final file = attachments[index];
                final url = file['url'] ?? '';
                final fileName =
                    file['name'] ?? (url.isNotEmpty ? _extractFileName(url) : 'file');

                final alreadyDownloaded = downloaded.contains(fileName);

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  color: AppCardTheme.surface,
                  elevation: AppCardTheme.elevation,
                  shape: AppCardTheme.shape,
                  child: ListTile(
                    leading: Icon(
                      alreadyDownloaded
                          ? Icons.check_circle
                          : Icons.insert_drive_file,
                      color: alreadyDownloaded ? Colors.green : Colors.blue,
                    ),
                    title: Text(fileName),
                    subtitle: alreadyDownloaded
                        ? const Text(
                      '✅ Già scaricato',
                      style: TextStyle(color: Colors.green),
                    )
                        : null,
                    onTap: () async {
                      if (url.isNotEmpty) {
                        await launchUrl(
                          Uri.parse(url),
                          mode: LaunchMode.externalApplication,
                        );
                      }

                      if (user != null && fileName.isNotEmpty) {
                        final docRef = FirebaseFirestore.instance
                            .collection('userProgress')
                            .doc(user.uid)
                            .collection('courses')
                            .doc(widget.courseId);

                        await docRef.set({
                          ...CourseProgressMeta.fields(
                            courseId: widget.courseId,
                            title: widget.courseTitle,
                            courseLabel: widget.courseLabel,
                            catalogCategory: widget.catalogCategory,
                          ),
                          'downloadCount': FieldValue.increment(1),
                          'updatedAt': FieldValue.serverTimestamp(),
                          'downloadedFiles':
                          FieldValue.arrayUnion([fileName]),
                        }, SetOptions(merge: true));
                      }
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// NAVIGATION BUTTON (ENUM + WIDGET)
// -----------------------------------------------------------------------------
enum NavAlignment { left, right }

class _NavButton extends StatelessWidget {
  final NavAlignment alignment;
  final String label;
  final String title;
  final bool enabled;
  final VoidCallback onTap;

  const _NavButton({
    required this.alignment,
    required this.label,
    required this.title,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
    enabled ? Colors.purple : Colors.purple.withValues(alpha: 0.4);

    final content = Row(
      children: alignment == NavAlignment.left
          ? [
        Icon(Icons.arrow_back_ios_new, color: textColor, size: 16),
        const SizedBox(width: 6),
        _texts(textColor, CrossAxisAlignment.start, TextAlign.left),
      ]
          : [
        _texts(textColor, CrossAxisAlignment.end, TextAlign.right),
        const SizedBox(width: 6),
        Icon(Icons.arrow_forward_ios, color: textColor, size: 16),
      ],
    );

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: enabled ? onTap : null,
      child: content,
    );
  }

  Widget _texts(
      Color textColor, CrossAxisAlignment align, TextAlign tAlign) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          title,
          textAlign: tAlign,
          style: TextStyle(color: textColor, fontSize: 13),
        ),
      ],
    );
  }
}
