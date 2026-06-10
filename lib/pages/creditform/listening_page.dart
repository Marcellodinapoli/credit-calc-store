import 'package:flutter/material.dart';
import 'personal_form_shell.dart';
import '../../core/theme/custom_tabbar_theme.dart';
import '../../core/dimensions.dart';
import '../../ui/layout/page_shell.dart';
import 'call_training_page.dart';
import 'contestation_training_page.dart';
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
  // ---------------------------------------------------------------------------
  // LIFECYCLE
  // ---------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _initState();
  }

  Future<void> _initState() async {
    // init mappa locale
    for (final c in _items) {
      _completed[c.id] = false;
    }

    // restore da Firestore
    final data = await ListeningProgressService.getContestazioniProgress();
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

// ---------------------------------------------------------------------------
// BUILD
// ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      thumbVisibility: true,
      child: ListView.separated(
      padding: Dimensions.scrollPadding(context),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final item = _items[index];
        return _ContestationCard(
          item: item,
          completed: _completed[item.id] ?? false,
          enabled: _isEnabled(index),
          onTap: () => _open(item, index),
        );
      },
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

