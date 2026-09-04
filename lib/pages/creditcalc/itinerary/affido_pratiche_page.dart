import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../models/gestionale_pratica.dart';
import '../../../services/creditcalc_gestionale_service.dart';
import 'affido_link_page.dart';
import 'affido_pratica_detail_page.dart';
import 'itinerary_page_shell.dart';

class AffidoPratichePage extends StatefulWidget {
  const AffidoPratichePage({super.key});

  @override
  State<AffidoPratichePage> createState() => _AffidoPratichePageState();
}

class _AffidoPratichePageState extends State<AffidoPratichePage>
    with WidgetsBindingObserver {
  final _svc = CreditCalcGestionaleService.instance;
  late Future<List<GestionalePraticaListItem>> _future;
  Timer? _poll;
  DateTime? _lastOkAt;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _future = _load();
    _poll = Timer.periodic(const Duration(seconds: 12), (_) {
      if (!mounted || _refreshing) return;
      unawaited(_reload(silent: true));
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_reload(silent: true));
    }
  }

  Future<List<GestionalePraticaListItem>> _load() async {
    final svc = _svc;
    try {
      await svc.ensureSession();
    } catch (_) {
      const storage = FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );
      final email = await storage.read(key: 'credit_calc_email') ??
          FirebaseAuth.instance.currentUser?.email;
      final password = await storage.read(key: 'credit_calc_password');
      if (email != null && password != null && password.isNotEmpty) {
        final ok = await svc.tryAutoLinkFromAppLogin(
          email: email,
          password: password,
        );
        if (!ok) rethrow;
      } else {
        rethrow;
      }
    }
    final items = await svc.listPratiche();
    _lastOkAt = DateTime.now();
    return items;
  }

  Future<void> _reload({bool silent = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    final next = _load();
    if (!silent && mounted) {
      setState(() => _future = next);
    }
    try {
      final items = await next;
      if (!mounted) return;
      setState(() {
        _future = Future.value(items);
        _lastOkAt = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() => _future = Future.error(e));
      }
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _disconnect() async {
    await _svc.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AffidoLinkPage()),
    );
  }

  String _fmtMoney(double? v) {
    if (v == null) return '—';
    return '€ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String _fmtClock(DateTime? dt) {
    if (dt == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }

  @override
  Widget build(BuildContext context) {
    const shell = ItineraryPageShell();
    final profile = _svc.cachedProfile;

    return shell.secondary(
      pageTitle: 'Pratiche in affido',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile != null
                            ? '${profile.name} · ${profile.email}'
                            : 'Sessione gestionale…',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      if (_lastOkAt != null)
                        Text(
                          'Aggiornato alle ${_fmtClock(_lastOkAt)}'
                          '${_refreshing ? ' · aggiornamento…' : ''}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black38,
                          ),
                        ),
                    ],
                  ),
                ),
                if (profile != null)
                  TextButton(
                    onPressed: _disconnect,
                    child: const Text('Scollega'),
                  ),
                IconButton(
                  tooltip: 'Aggiorna ora',
                  onPressed: _refreshing ? null : () => _reload(),
                  icon: _refreshing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<GestionalePraticaListItem>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done &&
                    !snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError && !snap.hasData) {
                  final msg = snap.error.toString();
                  final needLink = msg.contains('Collega') ||
                      msg.contains('autorizzato') ||
                      msg.contains('401') ||
                      msg.contains('403') ||
                      msg.contains('Sessione');
                  return ListView(
                    padding: ItineraryPageShell.listPadding(context),
                    children: [
                      Text(msg, style: TextStyle(color: Colors.red.shade800)),
                      const SizedBox(height: 16),
                      if (needLink)
                        FilledButton(
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const AffidoLinkPage(),
                              ),
                            );
                          },
                          child: const Text('Collega account'),
                        )
                      else
                        FilledButton(
                          onPressed: () => _reload(),
                          child: const Text('Riprova'),
                        ),
                    ],
                  );
                }
                final items = snap.data ?? const [];
                return RefreshIndicator(
                  onRefresh: () => _reload(),
                  child: items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: ItineraryPageShell.listPadding(context),
                          children: [
                            const SizedBox(height: 24),
                            const Text(
                              'Nessuna pratica in affido a questo account.',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              profile != null
                                  ? 'Assicurati di aver affidato la pratica '
                                      'all’operatore ${profile.email} nel gestionale, '
                                      'poi trascina verso il basso o tocca Aggiorna.'
                                  : 'Trascina verso il basso per aggiornare.',
                              style: const TextStyle(
                                color: Colors.black54,
                                height: 1.4,
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: ItineraryPageShell.listPadding(context),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final p = items[i];
                            return Card(
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                title: Text(
                                  p.debitore?.isNotEmpty == true
                                      ? p.debitore!
                                      : (p.numero ?? 'Pratica'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        [
                                          if (p.numero != null)
                                            'N. ${p.numero}',
                                          if (p.stato != null) p.stato,
                                          if (p.codiceScarico != null)
                                            'Scarico ${p.codiceScarico}',
                                        ].join(' · '),
                                        style: const TextStyle(height: 1.35),
                                      ),
                                      Text(
                                        'Residuo ${_fmtMoney(p.residuo)}'
                                        '${p.mandanteCodice != null ? ' · ${p.mandanteCodice}' : ''}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => AffidoPraticaDetailPage(
                                        praticaId: p.id,
                                        titlePreview: p.debitore ?? p.numero,
                                      ),
                                    ),
                                  );
                                  if (mounted) await _reload(silent: true);
                                },
                              ),
                            );
                          },
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
