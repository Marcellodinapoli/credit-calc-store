import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/read_state_service.dart';
import 'package:credit_calc_core/credit_calc_core.dart';
import 'personal_area_shell.dart';

/// Pagina Assistenza diretta
class DirectSupportPage extends StatefulWidget {
  const DirectSupportPage({super.key});

  @override
  State<DirectSupportPage> createState() => _DirectSupportPageState();
}

class _DirectSupportPageState extends State<DirectSupportPage> {
  final user = FirebaseAuth.instance.currentUser;
  int _lastSeen = 0;
  bool _readStateReady = false;

  final Map<String, TextEditingController> _replyControllers = {};

  @override
  void initState() {
    super.initState();
    _initReadState();
  }

  Future<void> _initReadState() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final storedLastSeen = await ReadStateService.getSupportLastSeenMs();

    if (!mounted) return;

    if (storedLastSeen == 0) {
      await ReadStateService.ensureSupportInitialized(now);
      setState(() {
        _lastSeen = now;
        _readStateReady = true;
      });
      return;
    }

    // Mostra subito i badge con l'ultima visita; aggiorna Firestore in background.
    setState(() {
      _lastSeen = storedLastSeen;
      _readStateReady = true;
    });
    ReadStateService.setSupportLastSeenMs(now);
  }

  String _contentTypeForExtension(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      default:
        return 'application/octet-stream';
    }
  }

  Future<Map<String, String>?> _uploadTicketAttachment({
    required String ticketId,
    required PlatformFile file,
  }) async {
    final bytes = file.bytes;
    if (bytes == null) return null;

    final safeName = file.name.replaceAll(RegExp(r'[^\w.\- ]'), '_');
    final ref = FirebaseStorage.instance.ref().child(
      'support/${user!.uid}/$ticketId/${DateTime.now().millisecondsSinceEpoch}_$safeName',
    );

    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: _contentTypeForExtension(file.extension),
      ),
    );

    final url = await ref.getDownloadURL();
    return {
      'attachmentUrl': url,
      'attachmentName': file.name,
      'attachmentContentType': _contentTypeForExtension(file.extension),
    };
  }

  Future<void> _openAttachment(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossibile aprire l\'allegato')),
      );
    }
  }

  Widget _buildAttachmentPreview(Map<String, dynamic> data) {
    final url = (data['attachmentUrl'] ?? '').toString();
    if (url.isEmpty) return const SizedBox.shrink();

    final name = (data['attachmentName'] ?? 'Allegato').toString();
    final contentType = (data['attachmentContentType'] ?? '').toString();
    final isImage = contentType.startsWith('image/') ||
        RegExp(r'\.(jpe?g|png|webp|gif)$', caseSensitive: false)
            .hasMatch(name);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: () => _openAttachment(url),
        child: Row(
          children: [
            Icon(
              isImage ? Icons.image_outlined : Icons.attach_file,
              size: 18,
              color: Colors.blue,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔹 Apertura dialog per nuovo ticket
  void _openNewTicketDialog() {
    final subjectCtrl = TextEditingController();
    final messageCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        PlatformFile? selectedFile;
        bool isSending = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickAttachment() async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: const [
                  'pdf',
                  'doc',
                  'docx',
                  'txt',
                  'jpg',
                  'jpeg',
                  'png',
                  'webp',
                  'gif',
                ],
                withData: true,
              );

              if (result == null || result.files.isEmpty) return;
              final file = result.files.single;
              if (file.bytes == null) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Impossibile leggere il file selezionato'),
                  ),
                );
                return;
              }

              setDialogState(() => selectedFile = file);
            }

            Future<void> submitTicket() async {
              final subject = subjectCtrl.text.trim();
              final message = messageCtrl.text.trim();
              if (subject.isEmpty || message.isEmpty) return;

              setDialogState(() => isSending = true);

              try {
                final docRef =
                    FirebaseFirestore.instance.collection('support').doc();

                await docRef.set({
                  'userId': user?.uid,
                  'userEmail': user?.email,
                  'subject': subject,
                  'createdAt': FieldValue.serverTimestamp(),
                  'status': 'open',
                });

                final messageData = <String, dynamic>{
                  'sender': 'user',
                  'text': message,
                  'timestamp': FieldValue.serverTimestamp(),
                };

                if (selectedFile != null) {
                  final attachment = await _uploadTicketAttachment(
                    ticketId: docRef.id,
                    file: selectedFile!,
                  );
                  if (attachment != null) {
                    messageData.addAll(attachment);
                  }
                }

                await docRef.collection('messages').add(messageData);

                if (!context.mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Ticket inviato con successo'),
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ Errore durante l\'invio del ticket: $e'),
                  ),
                );
              } finally {
                if (context.mounted) {
                  setDialogState(() => isSending = false);
                }
              }
            }

            return AlertDialog(
              title: const Text('Apri un ticket di supporto'),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: subjectCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Oggetto',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: messageCtrl,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Messaggio',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: isSending ? null : pickAttachment,
                        icon: const Icon(Icons.attach_file),
                        label: Text(
                          selectedFile?.name ?? 'Allega documento o immagine',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (selectedFile != null) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed:
                                isSending ? null : () => setDialogState(() {
                                      selectedFile = null;
                                    }),
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Rimuovi allegato'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSending ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Annulla'),
                ),
                FilledButton.icon(
                  icon: isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(isSending ? 'Invio...' : 'Invia'),
                  onPressed: isSending ? null : submitTicket,
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 🔹 Modifica ticket
  void _editTicket(String ticketId, String currentSubject) async {
    final subjectCtrl = TextEditingController(text: currentSubject);
    final messagesSnapshot = await FirebaseFirestore.instance
        .collection('support')
        .doc(ticketId)
        .collection('messages')
        .orderBy('timestamp')
        .limit(1)
        .get();

    String currentMessage = '';
    String? firstMessageId;
    if (messagesSnapshot.docs.isNotEmpty) {
      final data = messagesSnapshot.docs.first.data();
      currentMessage = data['text'] ?? '';
      firstMessageId = messagesSnapshot.docs.first.id;
    }

    final messageCtrl = TextEditingController(text: currentMessage);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Modifica ticket"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: subjectCtrl,
                decoration: const InputDecoration(
                  labelText: "Oggetto",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: "Messaggio",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annulla"),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.save),
            label: const Text("Salva"),
            onPressed: () async {
              final newSubject = subjectCtrl.text.trim();
              final newMessage = messageCtrl.text.trim();
              if (newSubject.isEmpty) return;

              try {
                await FirebaseFirestore.instance
                    .collection('support')
                    .doc(ticketId)
                    .update({'subject': newSubject});

                if (firstMessageId != null) {
                  await FirebaseFirestore.instance
                      .collection('support')
                      .doc(ticketId)
                      .collection('messages')
                      .doc(firstMessageId)
                      .update({'text': newMessage});
                }

                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("✅ Ticket aggiornato con successo"),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("❌ Errore durante la modifica: $e"),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  /// 🔹 Elimina ticket
  Future<void> _deleteTicket(String ticketId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Conferma eliminazione"),
        content: const Text(
            "Sei sicuro di voler eliminare definitivamente questo ticket?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annulla"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Elimina"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('support')
          .doc(ticketId)
          .delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("🗑️ Ticket eliminato")),
      );
    }
  }

  /// 🔹 Box risposta
  Widget _buildReplyBox(String ticketId) {
    _replyControllers[ticketId] ??= TextEditingController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const Text("Rispondi:", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _replyControllers[ticketId],
          maxLines: 2,
          decoration: InputDecoration(
            hintText: "Scrivi una risposta...",
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            icon: const Icon(Icons.send),
            label: const Text("Invia"),
            onPressed: () async {
              final text = _replyControllers[ticketId]!.text.trim();
              if (text.isEmpty) return;

              await FirebaseFirestore.instance
                  .collection('support')
                  .doc(ticketId)
                  .collection('messages')
                  .add({
                'sender': 'user',
                'text': text,
                'timestamp': FieldValue.serverTimestamp(),
              });

              _replyControllers[ticketId]!.clear();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingTicketsPlaceholder() {
    return ListView.builder(
      itemCount: 3,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Card(
          color: AppCardTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 16,
                  width: 220,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 12,
                  width: 140,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(),
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessagesLoadingPlaceholder() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return PersonalAreaShell(
      pageTitle: "Assistenza diretta",
      body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text("Nuovo ticket"),
                onPressed: _openNewTicketDialog,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('support')
                    .where('userId', isEqualTo: user?.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return _buildLoadingTicketsPlaceholder();
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("Nessun ticket ancora inviato"));
                  }

                  final tickets = snapshot.data!.docs;
                  tickets.sort((a, b) {
                    final ta = (a['createdAt'] as Timestamp?)?.toDate() ??
                        DateTime(2000);
                    final tb = (b['createdAt'] as Timestamp?)?.toDate() ??
                        DateTime(2000);
                    return tb.compareTo(ta);
                  });

                  return ListView.builder(
                    itemCount: tickets.length,
                    itemBuilder: (context, index) {
                      final ticket = tickets[index];
                      final ticketId = ticket.id;
                      final subject = ticket['subject'] ?? '';
                      final status = ticket['status'] ?? 'open';
                      final createdAt = (ticket['createdAt'] as Timestamp?)
                          ?.toDate()
                          .toLocal();

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Stack(
                          children: [
                            Align(
                              alignment: Alignment.topCenter,
                              child: ConstrainedBox(
                                constraints:
                                const BoxConstraints(maxWidth: 1300),
                                child: Card(
                                  color: AppCardTheme.surface,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                subject,
                                                style: TextStyle(
                                                  fontSize:
                                                  isMobile ? 14 : 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4),
                                              decoration: BoxDecoration(
                                                color: status == 'closed'
                                                    ? Colors.grey
                                                    : Colors.green,
                                                borderRadius:
                                                BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                status == 'closed'
                                                    ? 'CHIUSO'
                                                    : 'APERTO',
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12),
                                              ),
                                            ),

                                            if (status == 'open') ...[
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.edit,
                                                  color: Colors.blueAccent,
                                                ),
                                                onPressed: () =>
                                                    _editTicket(ticketId, subject),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete,
                                                  color: Colors.redAccent,
                                                ),
                                                onPressed: () =>
                                                    _deleteTicket(ticketId),
                                              ),
                                            ],
                                          ],
                                        ),

                                        if (createdAt != null)
                                          Text(
                                            "Inviato il ${createdAt.day.toString().padLeft(2, '0')}/"
                                                "${createdAt.month.toString().padLeft(2, '0')}/"
                                                "${createdAt.year} alle "
                                                "${createdAt.hour.toString().padLeft(2, '0')}:"
                                                "${createdAt.minute.toString().padLeft(2, '0')}",
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.black54),
                                          ),

                                        const Divider(),

                                        StreamBuilder<QuerySnapshot>(
                                          stream: ticket.reference
                                              .collection('messages')
                                              .orderBy('timestamp')
                                              .snapshots(),
                                          builder: (context, msgSnap) {
                                            if (msgSnap.connectionState ==
                                                    ConnectionState.waiting &&
                                                !msgSnap.hasData) {
                                              return _buildMessagesLoadingPlaceholder();
                                            }

                                            if (!msgSnap.hasData) {
                                              return const SizedBox.shrink();
                                            }

                                            final msgs = msgSnap.data!.docs;

                                            return Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                ...msgs.map((m) {
                                                  final data = m.data()
                                                  as Map<String, dynamic>;
                                                  final sender =
                                                  data['sender'];
                                                  final text =
                                                      data['text'] ?? '';
                                                  final isUser =
                                                      sender == 'user';

                                                  Timestamp? ts;
                                                  final rawTime =
                                                  data['timestamp'];
                                                  if (rawTime
                                                  is Timestamp) {
                                                    ts = rawTime;
                                                  }

                                                  final isNew = _readStateReady &&
                                                      !isUser &&
                                                      ts != null &&
                                                      ts.millisecondsSinceEpoch >
                                                          _lastSeen;

                                                  return Container(
                                                    margin:
                                                    const EdgeInsets
                                                        .symmetric(
                                                        vertical: 4),
                                                    padding:
                                                    const EdgeInsets.all(8),
                                                    decoration:
                                                    BoxDecoration(
                                                      color: isUser
                                                          ? Colors.white
                                                          : Colors.blue
                                                          .shade50,
                                                      borderRadius:
                                                      BorderRadius
                                                          .circular(8),
                                                      border: Border.all(
                                                          color: Colors
                                                              .grey.shade300),
                                                    ),
                                                    child: Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Icon(
                                                          isUser
                                                              ? Icons
                                                                  .person_outline
                                                              : Icons
                                                                  .support_agent,
                                                          color: isUser
                                                              ? Colors.grey
                                                              : Colors.blue,
                                                          size: 18,
                                                        ),
                                                        const SizedBox(
                                                            width: 8),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                isUser
                                                                    ? "Tu"
                                                                    : "Assistenza",
                                                                style:
                                                                    TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  color: isUser
                                                                      ? Colors
                                                                          .black87
                                                                      : Colors
                                                                          .blue,
                                                                ),
                                                              ),
                                                              if (text
                                                                  .isNotEmpty)
                                                                Text(text),
                                                              _buildAttachmentPreview(
                                                                  data),
                                                            ],
                                                          ),
                                                        ),
                                                        if (!isUser)
                                                          SizedBox(
                                                            width: 48,
                                                            child: isNew
                                                                ? Align(
                                                                    alignment:
                                                                        Alignment
                                                                            .topRight,
                                                                    child:
                                                                        Container(
                                                                      padding: const EdgeInsets
                                                                          .symmetric(
                                                                        horizontal:
                                                                            8,
                                                                        vertical:
                                                                            2,
                                                                      ),
                                                                      decoration:
                                                                          BoxDecoration(
                                                                        color: Colors
                                                                            .redAccent,
                                                                        borderRadius:
                                                                            BorderRadius.circular(
                                                                          12,
                                                                        ),
                                                                      ),
                                                                      child:
                                                                          const Text(
                                                                        'NEW',
                                                                        style:
                                                                            TextStyle(
                                                                          color: Colors
                                                                              .white,
                                                                          fontSize:
                                                                              10,
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  )
                                                                : const SizedBox
                                                                    .shrink(),
                                                          ),
                                                      ],
                                                    ),
                                                  );
                                                }),

                                                /// Box risposta se ticket aperto
                                                if (status == 'open')
                                                  _buildReplyBox(ticketId),
                                              ],
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
    );
  }
}
