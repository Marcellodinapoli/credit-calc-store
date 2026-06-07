import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/read_state_service.dart';
import 'personal_area_shell.dart';
import 'community_topic_page.dart';

/// Pagina Community (discussioni tra utenti)
class CommunityListPage extends StatefulWidget {
  const CommunityListPage({super.key});

  @override
  State<CommunityListPage> createState() => _CommunityListPageState();
}

class _CommunityListPageState extends State<CommunityListPage> {
  User? get user => FirebaseAuth.instance.currentUser;

  String _userName = 'Utente';

  Map<String, int> _topicLastSeen = {};
  bool _readStateReady = false;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _topics = [];
  bool _topicsLoading = true;
  String? _topicsError;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _approvedSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _mineSub;
  QuerySnapshot<Map<String, dynamic>>? _approvedSnap;
  QuerySnapshot<Map<String, dynamic>>? _mineSnap;

  bool get isAdmin =>
      user?.email == 'marcellodinapoli@tin.it';

  @override
  void initState() {
    super.initState();
    _loadTopicLastSeen();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((authUser) {
      if (authUser != null) {
        _loadUserName();
        _listenTopics();
      } else {
        _approvedSub?.cancel();
        _mineSub?.cancel();
        if (!mounted) return;
        setState(() {
          _topicsLoading = false;
          _topicsError = 'Utente non autenticato.';
          _topics = [];
        });
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _approvedSub?.cancel();
    _mineSub?.cancel();
    super.dispose();
  }

  void _listenTopics() {
    _approvedSub?.cancel();
    _mineSub?.cancel();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() {
      _topicsLoading = true;
      _topicsError = null;
    });

    void onStreamError(Object error) {
      if (!mounted) return;
      setState(() {
        _topicsLoading = false;
        _topicsError = error.toString();
      });
    }

    // Feed social: argomenti approvati visibili a tutti
    _approvedSub = FirebaseFirestore.instance
        .collection('community')
        .where('status', isEqualTo: 'approved')
        .snapshots()
        .listen(
      (snap) {
        _approvedSnap = snap;
        _mergeTopics();
      },
      onError: onStreamError,
    );

    // Argomenti propri ancora in revisione
    _mineSub = FirebaseFirestore.instance
        .collection('community')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .listen(
      (snap) {
        _mineSnap = snap;
        _mergeTopics();
      },
      onError: onStreamError,
    );
  }

  void _mergeTopics() {
    if (!mounted) return;

    final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in _approvedSnap?.docs ?? const []) {
      byId[doc.id] = doc;
    }
    for (final doc in _mineSnap?.docs ?? const []) {
      byId[doc.id] = doc;
    }

    final merged = byId.values.toList()
      ..sort((a, b) {
        final ta = a.data()['createdAt'];
        final tb = b.data()['createdAt'];
        if (ta is Timestamp && tb is Timestamp) {
          return tb.compareTo(ta);
        }
        return 0;
      });

    setState(() {
      _topics = merged;
      _topicsLoading = false;
      _topicsError = null;
    });
  }

  Future<void> _loadTopicLastSeen() async {
    _topicLastSeen = await ReadStateService.getCommunityTopicsLastSeen();
    if (!mounted) return;
    setState(() => _readStateReady = true);
  }

  Future<void> _loadUserName() async {
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();

      if (doc.exists) {
        setState(() {
          _userName = doc.data()?['name'] ?? 'Utente';
        });
      }
    } catch (_) {}
  }

  void _openNewTopicDialog() {
    final titleCtrl = TextEditingController();
    final messageCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Nuovo argomento"),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: "Titolo argomento",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: messageCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: "Messaggio iniziale",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annulla"),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.send),
              label: const Text("Pubblica"),
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final message = messageCtrl.text.trim();
                if (title.isEmpty || message.isEmpty) return;

                if (user == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Utente non autenticato'),
                    ),
                  );
                  return;
                }

                final topicsRef =
                FirebaseFirestore.instance.collection('community');
                final topicDoc = topicsRef.doc();

                await topicDoc.set({
                  'title': title,
                  'createdBy': _userName,
                  'userId': user!.uid,
                  'createdAt': FieldValue.serverTimestamp(),
                  'status': 'pending',
                });

                await topicDoc.collection('messages').add({
                  'text': message,
                  'userId': user!.uid,
                  'userName': _userName,
                  'timestamp': FieldValue.serverTimestamp(),
                });

                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("✅ Argomento inviato per approvazione"),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  //  FIX DEFINITIVO
  void _openTopicMessages(DocumentSnapshot topic) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CommunityTopicPage(
          topicId: topic.id,
          topicTitle: topic['title'] ?? 'Discussione',
        ),
      ),
    );

    final now = DateTime.now().millisecondsSinceEpoch;
    await ReadStateService.setCommunityTopicLastSeenMs(topic.id, now);
    setState(() => _topicLastSeen[topic.id] = now);
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'approved':
        return "Approvato";
      case 'rejected':
        return "Rifiutato";
      default:
        return "In revisione";
    }
  }

  Widget _buildLoadingTopicsPlaceholder() {
    return ListView.builder(
      itemCount: 4,
      itemBuilder: (_, __) => Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: ListTile(
          title: Container(
            height: 16,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              height: 12,
              width: 180,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PersonalAreaShell(
      pageTitle: "Community",
      body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text("Nuovo argomento"),
                onPressed: _openNewTopicDialog,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _topicsLoading
                  ? _buildLoadingTopicsPlaceholder()
                  : _topicsError != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Errore caricamento community:\n$_topicsError',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        )
                      : _topics.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'Nessun argomento nel feed.\n\n'
                                  'Qui compaiono gli argomenti approvati, '
                                  'visibili a tutti gli utenti.\n'
                                  'Se ne hai creato uno, resta "In revisione" '
                                  'finché non viene approvato.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            )
                          : _buildTopicsList(),
            ),
          ],
        ),
    );
  }

  Widget _buildTopicsList() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return ListView.builder(
      itemCount: _topics.length,
      itemBuilder: (context, index) {
        final topic = _topics[index];
        final title = topic['title'] ?? 'Argomento';
        final status = topic['status'] ?? 'pending';
        final author = (topic['createdBy'] ?? 'Utente').toString();

        return StreamBuilder<QuerySnapshot>(
          stream: topic.reference.collection('messages').snapshots(),
          builder: (context, msgSnap) {
            if (msgSnap.hasError) {
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  title: Text(title),
                  subtitle: Text('di $author • errore messaggi'),
                ),
              );
            }

            final docs = msgSnap.data?.docs ?? [];

                final lastSeen = _topicLastSeen[topic.id] ?? 0;

                final unreadCount = _readStateReady && lastSeen > 0
                    ? docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final ts = data['timestamp'] as Timestamp?;
                        final senderId = data['userId'];

                        return ts != null &&
                            senderId != currentUid &&
                            ts.millisecondsSinceEpoch > lastSeen;
                      }).length
                    : 0;

                final hasNew = unreadCount > 0;
                final totalComments = docs.length;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (hasNew)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text('di $author • $totalComments commenti'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 10,
                          color: _statusColor(status),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _statusText(status),
                          style: TextStyle(
                            fontSize: 12,
                            color: _statusColor(status),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chat_outlined),
                          onPressed: () => _openTopicMessages(topic),
                        ),
                      ],
                    ),
                  ),
                );
          },
        );
      },
    );
  }
}