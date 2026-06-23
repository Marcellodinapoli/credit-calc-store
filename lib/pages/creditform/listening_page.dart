import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'personal_form_shell.dart';
import '../../core/theme/custom_tabbar_theme.dart';
import '../../core/dimensions.dart';
import '../../ui/layout/page_shell.dart';
import '../../models/warmup_contestation.dart';
import '../../services/warmup_contestation_service.dart';
import 'call_training_page.dart';
import 'contestation_training_page.dart';
import 'user_contestation_form_page.dart';
import '../../services/listening_progress_service.dart';


class ListeningPage extends StatefulWidget {
  const ListeningPage({super.key});

  @override
  State<ListeningPage> createState() => _ListeningPageState();
}

class _ListeningPageState extends State<ListeningPage>
    with SingleTickerProviderStateMixin {

  // ---------------------------------------------------------------------------
  // STATE
  // ---------------------------------------------------------------------------
  TabController? _tab;
  bool _loading = true;

  // ---------------------------------------------------------------------------
// LIFECYCLE
// ---------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _initTab();
  }

  void _initTab() {
    // 🔒 NIENTE persistenza della tab
    // La tab serve solo per navigazione UI, non come stato logico

    _tab = TabController(
      length: 3,
      vsync: this,
      initialIndex: 0, // sempre prima tab
    );

    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _tab?.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (_loading || _tab == null) {
      return const SizedBox.shrink();
    }

    return PersonalFormShell(
      pageTitle: "Warm-up",
      body: Column(
        children: [
          const SizedBox(height: 8),
          CustomTabBarTheme.build(
            context: context,
            controller: _tab!,
            isScrollable: true,
            tabs: const [
              Tab(text: 'Telefonata'),
              Tab(text: 'Contestazioni nel sollecito'),
              Tab(text: 'Contestazioni nel recupero'),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tab!,
              children: const [
                TelefonataTab(),
                ContestazioniTab(),
                ContestazioniTab(isRecupero: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
/// ===========================================================================
/// TAB TELEFONATA
/// ===========================================================================

class TelefonataTab extends StatefulWidget {
  const TelefonataTab({super.key});

  @override
  State<TelefonataTab> createState() => _TelefonataTabState();
}

class _TelefonataTabState extends State<TelefonataTab> {
  final _scrollController = ScrollController();

  // ---------------------------------------------------------------------------
  // STATE
  // ---------------------------------------------------------------------------
  final Map<String, bool> _completed = {
    "Approccio": false,
    "Presentazione": false,
    "Presentazione_standard": false,
    "Presentazione_privacy": false,
    "Negoziazione": false,
    "Chiusura": false,
  };

  // ---------------------------------------------------------------------------
  // LIFECYCLE
  // ---------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _restoreProgress();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onPresentazioneExpansion(bool expanded) {
    if (!expanded) return;

    // Due frame: attende il ridisegno dopo l'animazione dell'ExpansionTile.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      });
    });
  }

  Future<void> _restoreProgress() async {
    final data = await ListeningProgressService.getTelefonataProgress();
    if (data.isEmpty) return;

    setState(() {
      for (final entry in data.entries) {
        if (_completed.containsKey(entry.key)) {
          _completed[entry.key] = entry.value;
        }
      }
    });
  }

  // ---------------------------------------------------------------------------
// HELPERS
// ---------------------------------------------------------------------------
  bool _isEnabled(String phase) {
    switch (phase) {
      case "Approccio":
        return true;
      case "Presentazione":
        return _completed["Approccio"]!;
      case "Negoziazione":
        return _completed["Presentazione_standard"]! &&
            _completed["Presentazione_privacy"]!;
      case "Chiusura":
        return _completed["Negoziazione"]!;
      default:
        return false;
    }
  }

  // ---------------------------------------------------------------------------
  // ACTIONS
  // ---------------------------------------------------------------------------
  Future<void> _openPhase(String key) async {
    final completed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CallTrainingPage(
          phaseKey: key,
        ),
      ),
    );

    if (completed == true) {
      setState(() => _completed[key] = true);
      await ListeningProgressService.setTelefonataCompleted(key);
    }
  }

  // ---------------------------------------------------------------------------
// BUILD
// ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final pad = Dimensions.scrollPadding(context);

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: pad,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          PhaseCard(
            title: "Approccio",
            subtitle: "Approfondisce la prima fase della telefonata",
            color: Colors.orange,
            completed: _completed["Approccio"]!,
            enabled: _isEnabled("Approccio"),
            onTap: () => _openPhase("Approccio"),
          ),
          const SizedBox(height: 16),

          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              onExpansionChanged: _onPresentazioneExpansion,
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: IgnorePointer(
                child: PhaseCard(
                  title: "Presentazione",
                  subtitle: "Approfondisce la seconda fase della telefonata",
                  color: Colors.blue,
                  completed: _completed["Presentazione_standard"]! ||
                      _completed["Presentazione_privacy"]!,
                  enabled: _isEnabled("Presentazione"),
                  onTap: () {},
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 20, bottom: 12),
                  child: PhaseCard(
                    title: "Presentazione standard",
                    subtitle:
                        "Presentazione al titolare: rispondi quando ti chiedono chi sei",
                    color: Colors.blue,
                    completed: _completed["Presentazione_standard"]!,
                    enabled: _isEnabled("Presentazione"),
                    onTap: () => _openPhase("Presentazione_standard"),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 20, bottom: 8),
                  child: PhaseCard(
                    title: "Presentazione privacy",
                    subtitle:
                        "Terza persona e legge sulla privacy: rispondi con iniziativa",
                    color: Colors.blue,
                    completed: _completed["Presentazione_privacy"]!,
                    enabled: _isEnabled("Presentazione"),
                    onTap: () => _openPhase("Presentazione_privacy"),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          PhaseCard(
            title: "Negoziazione",
            subtitle: "Approfondisce la terza fase della telefonata",
            color: Colors.deepPurple,
            completed: _completed["Negoziazione"]!,
            enabled: _isEnabled("Negoziazione"),
            onTap: () => _openPhase("Negoziazione"),
          ),
          const SizedBox(height: 16),
          PhaseCard(
            title: "Chiusura",
            subtitle: "Approfondisce la quarta fase della telefonata",
            color: Colors.green,
            completed: _completed["Chiusura"]!,
            enabled: _isEnabled("Chiusura"),
            onTap: () => _openPhase("Chiusura"),
          ),
        ],
        ),
      ),
    );
  }
}
/// ===========================================================================
/// PHASE CARD (TELEFONATA) — INVARIATA
/// ===========================================================================

class PhaseCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final bool completed;
  final bool enabled;
  final VoidCallback onTap;

  const PhaseCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.completed,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = enabled ? color : Colors.grey;

    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: enabled ? 3 : 0,
        color: enabled ? Colors.white : Colors.grey.shade100,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 60,
                  decoration: BoxDecoration(
                    color: effectiveColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: effectiveColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color:
                          enabled ? Colors.black54 : Colors.black26,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  completed
                      ? Icons.check_circle
                      : enabled
                      ? Icons.radio_button_unchecked
                      : Icons.lock,
                  color: completed ? Colors.green : Colors.black26,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ContestazioniTab extends StatefulWidget {
  final bool isRecupero;

  const ContestazioniTab({super.key, this.isRecupero = false});

  @override
  State<ContestazioniTab> createState() => _ContestazioniTabState();
}

class _ContestazioniTabState extends State<ContestazioniTab> {

  // ---------------------------------------------------------------------------
// STATE
// ---------------------------------------------------------------------------
  List<ContestationItem> get _items => widget.isRecupero ? [] : const [
    ContestationItem(
      id: 'ritardo',
      title: 'Un giorno di ritardo',
      subtitle: 'Contestazione sulle morosità applicate subito',
      category: ContestationCategory.amministrativa,
    ),
    ContestationItem(
      id: 'agenzia',
      title: 'Agenzia debiti',
      subtitle: 'Coinvolgimento di terzi o richiesta rata singola',
      category: ContestationCategory.legale,
    ),
    ContestationItem(
      id: 'coobbligato',
      title: 'Coobbligato',
      subtitle: 'Richiesta di contattare l’intestatario',
      category: ContestationCategory.amministrativa,
    ),
    ContestationItem(
      id: 'prodotto',
      title: 'Prodotto difettoso',
      subtitle: 'Rifiuto pagamento per problema sul bene',
      category: ContestationCategory.generica,
    ),
    ContestationItem(
      id: 'pagamento',
      title: 'Pagamento generico',
      subtitle: 'Promessa non concreta di pagamento',
      category: ContestationCategory.generica,
    ),
    ContestationItem(
      id: 'economica',
      title: 'Difficoltà economica',
      subtitle: 'Situazione lavorativa o reddito insufficiente',
      category: ContestationCategory.economica,
    ),
  ];

  final Map<String, bool> _completed = {};
  List<WarmupContestation> _userContestations = [];
  StreamSubscription<List<WarmupContestation>>? _userSub;
  String? _uid;

  WarmupContestationContext get _context => widget.isRecupero
      ? WarmupContestationContext.recupero
      : WarmupContestationContext.sollecito;

  // ---------------------------------------------------------------------------
  // LIFECYCLE
  // ---------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    _listenUserContestations();
    _initState();
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }

  void _listenUserContestations() {
    _userSub?.cancel();
    _userSub = WarmupContestationService.watchForContext(_context).listen((list) {
      if (mounted) setState(() => _userContestations = list);
    });
  }

  Future<void> _initState() async {
    for (final c in _items) {
      _completed[c.id] = false;
    }

    final data = await ListeningProgressService.getContestazioniProgress();
    if (!mounted) return;

    setState(() {
      for (final entry in data.entries) {
        if (_completed.containsKey(entry.key) ||
            entry.key.startsWith('uc_')) {
          _completed[entry.key] = entry.value;
        }
      }
    });
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------
  bool get _allBuiltinCompleted {
    if (_items.isEmpty) return true;
    return _items.every((c) => _completed[c.id] == true);
  }

  List<WarmupContestation> get _mine {
    final uid = _uid;
    if (uid == null) return [];
    return _userContestations.where((c) => c.authorUid == uid).toList();
  }

  List<WarmupContestation> get _communityApproved {
    final uid = _uid;
    return _userContestations
        .where(
          (c) =>
              c.status == WarmupContestationStatus.approved &&
              c.authorUid != uid,
        )
        .toList();
  }

  bool _isEnabled(int index) {
    if (index == 0) return true;
    return _completed[_items[index - 1].id] == true;
  }

  ContestationTrainingItem _mapTrainingItem(ContestationItem item) {
    switch (item.id) {
      case 'no_work':
        return const ContestationTrainingItem(
          title: 'Non sto lavorando',
          declared: '«Non sto lavorando, quindi non posso pagare.»',
          meaning:
          'Il cliente sposta la trattativa sulla propria condizione personale.',
          risk:
          'Rinvio indefinito della chiamata senza verifica concreta.',
          objective:
          'Mantenere il controllo e riportare il dialogo su ciò che è possibile.',
          response:
          '«Capisco la situazione, vediamo insieme cosa è sostenibile oggi.»',
        );
      case 'lawyer':
        return const ContestationTrainingItem(
          title: 'Ho incaricato un avvocato',
          declared: '«Ho già dato mandato al mio avvocato.»',
          meaning:
          'Tentativo di chiusura difensiva della conversazione.',
          risk:
          'Blocco totale del dialogo se accettato passivamente.',
          objective:
          'Verificare se il legale è realmente operativo sulla posizione.',
          response:
          '«Perfetto, verifichiamo insieme a che punto è la pratica.»',
        );
      default:
        return ContestationTrainingItem(
          title: item.title,
          declared: item.title,
          meaning: 'Analisi della contestazione.',
          risk: 'Rischio comunicativo.',
          objective: 'Gestione corretta della risposta.',
          response: 'Risposta professionale e controllata.',
        );
    }
  }

  ContestationTrainingItem _trainingItemFromUser(WarmupContestation c) {
    return ContestationTrainingItem(
      title: c.title,
      declared: c.declared,
      meaning: c.meaning,
      risk: c.risk,
      objective: c.objective,
      response: c.response,
    );
  }

  // ---------------------------------------------------------------------------
  // ACTIONS
  // ---------------------------------------------------------------------------
  Future<void> _open(ContestationItem item, int index) async {
    if (!_isEnabled(index)) return;

    final completed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ContestationTrainingPage(
          item: _mapTrainingItem(item),
        ),
      ),
    );

    if (completed == true) {
      setState(() => _completed[item.id] = true);
      await ListeningProgressService.setContestationCompleted(item.id);
    }
  }

  Future<void> _openUser(WarmupContestation contestation) async {
    if (contestation.canEdit) {
      final action = await showModalBottomSheet<String>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.school_outlined),
                title: const Text('Allenati'),
                onTap: () => Navigator.pop(ctx, 'train'),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Modifica'),
                onTap: () => Navigator.pop(ctx, 'edit'),
              ),
              if (contestation.canDelete)
                ListTile(
                  leading: Icon(Icons.delete_outline, color: Colors.red.shade700),
                  title: Text(
                    'Elimina',
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                  onTap: () => Navigator.pop(ctx, 'delete'),
                ),
            ],
          ),
        ),
      );

      if (!mounted) return;

      if (action == 'edit') {
        await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => UserContestationFormPage(
              context: _context,
              existing: contestation,
            ),
          ),
        );
        return;
      }

      if (action == 'delete') {
        try {
          await WarmupContestationService.delete(contestation.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Contestazione eliminata.')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.toString())),
            );
          }
        }
        return;
      }

      if (action != 'train') return;
    }

    final completed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ContestationTrainingPage(
          item: _trainingItemFromUser(contestation),
        ),
      ),
    );

    if (completed == true) {
      setState(() => _completed[contestation.progressKey] = true);
      await ListeningProgressService.setContestationCompleted(
        contestation.progressKey,
      );
    }
  }

  Future<void> _addUserContestation() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => UserContestationFormPage(context: _context),
      ),
    );
  }

// ---------------------------------------------------------------------------
// BUILD
// ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (i > 0) children.add(const SizedBox(height: 16));
      children.add(
        _ContestationCard(
          item: item,
          completed: _completed[item.id] ?? false,
          enabled: _isEnabled(i),
          onTap: () => _open(item, i),
        ),
      );
    }

    final mine = _mine;
    final community = _communityApproved;
    if (mine.isNotEmpty || community.isNotEmpty) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 24));
      children.add(
        Text(
          'Contestazioni personali e community',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: Colors.grey.shade800,
          ),
        ),
      );
      children.add(const SizedBox(height: 12));
    }

    for (final c in mine) {
      children.add(const SizedBox(height: 16));
      children.add(
        _UserContestationCard(
          contestation: c,
          completed: _completed[c.progressKey] ?? false,
          isMine: true,
          onTap: () => _openUser(c),
        ),
      );
    }

    for (final c in community) {
      children.add(const SizedBox(height: 16));
      children.add(
        _UserContestationCard(
          contestation: c,
          completed: _completed[c.progressKey] ?? false,
          isMine: false,
          onTap: () => _openUser(c),
        ),
      );
    }

    if (_allBuiltinCompleted) {
      children.add(const SizedBox(height: 24));
      children.add(
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.orange.shade200),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _addUserContestation,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.add_circle_outline, color: Colors.orange.shade800),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Aggiungi la tua contestazione',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: Colors.orange.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Racconta un caso reale nel contesto '
                          '${_context.label.toLowerCase()}. Visibile subito a te; '
                          'condivisa con tutti dopo approvazione BK.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            height: 1.4,
                          ),
                        ),
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

    return Scrollbar(
      thumbVisibility: true,
      child: ListView(
        padding: Dimensions.scrollPadding(context),
        children: children,
      ),
    );
  }
}

/// ===========================================================================
/// MODEL
/// ===========================================================================

class ContestationItem {
  final String id;
  final String title;
  final String subtitle;
  final ContestationCategory category;

  const ContestationItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
  });
}

enum ContestationCategory {
  economica,
  legale,
  salute,
  amministrativa,
  generica,
}

/// ===========================================================================
/// USER CONTESTATION CARD
/// ===========================================================================

class _UserContestationCard extends StatelessWidget {
  const _UserContestationCard({
    required this.contestation,
    required this.completed,
    required this.isMine,
    required this.onTap,
  });

  final WarmupContestation contestation;
  final bool completed;
  final bool isMine;
  final VoidCallback onTap;

  Color _categoryColor() {
    return switch (contestation.category) {
      WarmupContestationCategory.economica => Colors.orange,
      WarmupContestationCategory.legale => Colors.blue,
      WarmupContestationCategory.salute => Colors.deepPurple,
      WarmupContestationCategory.amministrativa => Colors.green,
      WarmupContestationCategory.generica => Colors.blueGrey,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor();
    final status = contestation.status;

    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isMine
              ? BorderSide(color: Colors.orange.shade100)
              : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 60,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              contestation.title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: color,
                              ),
                            ),
                          ),
                          if (isMine)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor(status).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                status.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _statusColor(status),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        contestation.declared,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                          height: 1.35,
                        ),
                      ),
                      if (isMine &&
                          status == WarmupContestationStatus.rejected &&
                          contestation.rejectionNote != null &&
                          contestation.rejectionNote!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Motivo rifiuto: ${contestation.rejectionNote}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade700,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  completed ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: completed ? Colors.green : Colors.black26,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(WarmupContestationStatus status) {
    return switch (status) {
      WarmupContestationStatus.draft => Colors.grey.shade700,
      WarmupContestationStatus.pendingReview => Colors.orange.shade800,
      WarmupContestationStatus.approved => Colors.green.shade700,
      WarmupContestationStatus.rejected => Colors.red.shade700,
    };
  }
}

/// ===========================================================================
/// CONTESTATION CARD — ALLINEATA A PHASE CARD
/// ===========================================================================

class _ContestationCard extends StatelessWidget {
  final ContestationItem item;
  final bool completed;
  final bool enabled;
  final VoidCallback onTap;

  const _ContestationCard({
    required this.item,
    required this.completed,
    required this.enabled,
    required this.onTap,
  });

  Color _categoryColor() {
    switch (item.category) {
      case ContestationCategory.economica:
        return Colors.orange;
      case ContestationCategory.legale:
        return Colors.blue;
      case ContestationCategory.salute:
        return Colors.deepPurple;
      case ContestationCategory.amministrativa:
        return Colors.green;
      case ContestationCategory.generica:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = _categoryColor();
    final effectiveColor = enabled ? baseColor : Colors.grey;

    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: enabled ? 3 : 0,
        color: enabled ? Colors.white : Colors.grey.shade100,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 60,
                  decoration: BoxDecoration(
                    color: effectiveColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: effectiveColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: enabled
                              ? Colors.black54
                              : Colors.black26,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  completed
                      ? Icons.check_circle
                      : enabled
                      ? Icons.radio_button_unchecked
                      : Icons.lock,
                  color: completed ? Colors.green : Colors.black26,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ===========================================================================
/// DETAIL PAGE — INVARIATA
/// ===========================================================================

class ContestationDetailPage extends StatelessWidget {
  final ContestationItem item;

  const ContestationDetailPage({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return SecondaryPageScaffold(
      pageTitle: item.title,
      project: BrandedPageProject.form,
      body: Center(
        child: FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Fine analisi'),
        ),
      ),
    );
  }
}

