import 'package:flutter/material.dart';

import '../../../models/gestionale_pratica.dart';
import '../../../services/creditcalc_gestionale_service.dart';
import '../../../widgets/voice_note_field.dart';
import 'itinerary_page_shell.dart';

enum _SchedaPratica {
  sintesi,
  debitore,
  garanti,
  contabile,
  estratto,
  pianoRate,
  note,
  documenti,
  lavorazione,
}

class AffidoPraticaDetailPage extends StatefulWidget {
  const AffidoPraticaDetailPage({
    super.key,
    required this.praticaId,
    this.titlePreview,
  });

  final String praticaId;
  final String? titlePreview;

  @override
  State<AffidoPraticaDetailPage> createState() =>
      _AffidoPraticaDetailPageState();
}

class _AffidoPraticaDetailPageState extends State<AffidoPraticaDetailPage> {
  final _svc = CreditCalcGestionaleService.instance;
  final _notaCtrl = TextEditingController();

  late Future<GestionalePraticaDetail> _future;
  _SchedaPratica? _open = _SchedaPratica.sintesi;
  String? _codiceScarico;
  bool _saving = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _future = _svc.getPratica(widget.praticaId);
  }

  @override
  void dispose() {
    _notaCtrl.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _svc.getPratica(widget.praticaId);
      _formError = null;
    });
  }

  void _toggle(_SchedaPratica s) {
    setState(() => _open = _open == s ? null : s);
  }

  String _money(double? v) {
    if (v == null) return '—';
    return '€ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String _when(DateTime? dt) {
    if (dt == null) return '—';
    final d = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  String _whenFull(DateTime? dt) {
    if (dt == null) return '';
    final d = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  String _cell(dynamic v) {
    if (v == null) return '—';
    final s = v.toString().trim();
    return s.isEmpty ? '—' : s;
  }

  Future<void> _salva() async {
    final nota = _notaCtrl.text.trim();
    final codice = _codiceScarico?.trim();
    if (nota.isEmpty && (codice == null || codice.isEmpty)) {
      setState(() => _formError = 'Inserisci una nota e/o un codice scarico');
      return;
    }
    setState(() {
      _saving = true;
      _formError = null;
    });
    try {
      await _svc.inviaLavorazione(
        praticaId: widget.praticaId,
        nota: nota.isEmpty ? null : nota,
        codiceScarico: codice,
      );
      if (!mounted) return;
      _notaCtrl.clear();
      setState(() => _codiceScarico = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Salvato sul gestionale')),
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      setState(() => _formError = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const shell = ItineraryPageShell();

    return shell.secondary(
      pageTitle: widget.titlePreview?.trim().isNotEmpty == true
          ? widget.titlePreview!.trim()
          : 'Pratica',
      body: FutureBuilder<GestionalePraticaDetail>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ListView(
              padding: ItineraryPageShell.listPadding(context),
              children: [
                Text(
                  snap.error.toString(),
                  style: TextStyle(color: Colors.red.shade800),
                ),
                const SizedBox(height: 12),
                FilledButton(onPressed: _reload, child: const Text('Riprova')),
              ],
            );
          }
          final d = snap.data!;
          return ListView(
            padding: ItineraryPageShell.listPadding(context),
            children: [
              Text(
                d.debitore.isNotEmpty ? d.debitore : 'Pratica',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  if (d.numero != null) 'N. ${d.numero}',
                  if (d.stato != null) d.stato,
                  if (d.residuo != null) 'Residuo ${_money(d.residuo)}',
                ].join(' · '),
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 12),
              _accordion(
                id: _SchedaPratica.sintesi,
                title: 'Sintesi',
                subtitle: d.stato,
                child: Column(
                  children: [
                    _kv('Numero', d.numero),
                    _kv('Stato', d.stato),
                    _kv('Codice scarico', d.codiceScarico),
                    _kv('Scarico il', _when(d.codiceScaricoAt)),
                    _kv('Residuo', _money(d.residuo)),
                    _kv('Mandante', d.mandante),
                    _kv('Lotto', d.numeroMandante),
                    _kv('Contratto', d.contratto),
                    _kv('Commessa', d.commessa),
                    _kv('Affido', _when(d.dataAffido)),
                    _kv('Scadenza', _when(d.scadenza)),
                    _kv('Assegnatario', d.assegnatarioName),
                    if (d.promessaAt != null || d.promessaImporto != null) ...[
                      _kv('Promessa', _when(d.promessaAt)),
                      _kv('Importo promessa', _money(d.promessaImporto)),
                      _kv('Metodo promessa', d.promessaMetodo),
                    ],
                  ],
                ),
              ),
              _accordion(
                id: _SchedaPratica.debitore,
                title: 'Debitore',
                subtitle: d.debitoreTelefono,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _kv('Nominativo', d.debitore),
                    _kv('Codice fiscale', d.debitoreCf),
                    _kv('Indirizzo', d.debitoreIndirizzo),
                    _kv('Telefono', d.debitoreTelefono),
                    _kv('Email', d.debitoreEmail),
                    if (d.debitoreRecapiti.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Altri recapiti',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      ...d.debitoreRecapiti.map((r) {
                        final tipo = _cell(r['Tipo'] ?? r['tipo']);
                        final val = _cell(r['Valore'] ?? r['valore']);
                        final stato = _cell(r['Stato'] ?? r['stato']);
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '$tipo: $val${stato != '—' ? ' ($stato)' : ''}',
                            style: const TextStyle(height: 1.35),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
              _accordion(
                id: _SchedaPratica.garanti,
                title: 'Garanti',
                subtitle: d.garanti.isEmpty
                    ? 'Nessuno'
                    : '${d.garanti.length}',
                child: d.garanti.isEmpty
                    ? const Text(
                        'Nessun garante su questa pratica.',
                        style: TextStyle(color: Colors.black54),
                      )
                    : Column(
                        children: d.garanti.map((g) {
                          final id = '${g['Id'] ?? g['id']}';
                          final nome =
                              '${g['Cognome'] ?? ''} ${g['Nome'] ?? ''}'
                                  .trim();
                          final recs = d.recapitiGarante(id);
                          return Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F9FC),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nome.isEmpty ? 'Garante' : nome,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                _kv('CF', _cell(g['CodiceFiscale'])),
                                _kv(
                                  'Indirizzo',
                                  [
                                    _cell(g['Indirizzo']),
                                    [
                                      _cell(g['Cap']),
                                      _cell(g['Citta']),
                                    ].where((x) => x != '—').join(' '),
                                    if (_cell(g['Provincia']) != '—')
                                      '(${_cell(g['Provincia'])})',
                                  ].where((x) => x != '—' && x.isNotEmpty).join(', '),
                                ),
                                _kv('Telefono', _cell(g['Telefono'])),
                                _kv('Email', _cell(g['Email'])),
                                ...recs.map(
                                  (r) => Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      '${_cell(r['Tipo'])}: ${_cell(r['Valore'])}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
              _accordion(
                id: _SchedaPratica.contabile,
                title: 'Contabile',
                subtitle: _money(d.residuo),
                child: Column(
                  children: [
                    _kv('Residuo', _money(d.residuo)),
                    _kv('Capitale', _money(d.capitale)),
                    _kv('Interessi / mora', _money(d.interessi)),
                    _kv('Spese', _money(d.spese)),
                    _kv('Spese recupero', _money(d.speseRecupero)),
                    _kv('Importo rata', _money(d.importoRata)),
                    _kv('Rate arretrate', _money(d.rateArretrate)),
                    _kv(
                      'Rate scadute (n.)',
                      d.numeroRateScadute?.toString(),
                    ),
                    _kv('Totale incassato', _money(d.totIncassato)),
                    _kv('Importo totale', _money(d.importoTotale)),
                    _kv('Netto da pagare', _money(d.nettoDaPagare)),
                  ],
                ),
              ),
              _accordion(
                id: _SchedaPratica.estratto,
                title: 'Estratto / movimenti',
                subtitle:
                    '${d.incassi.length} incassi · ${d.fatture.length} fatture',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Incassi',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    if (d.incassi.isEmpty)
                      const Text(
                        'Nessun incasso.',
                        style: TextStyle(color: Colors.black54),
                      )
                    else
                      ...d.incassi.take(20).map((i) {
                        final data = _when(
                          DateTime.tryParse('${i['Data'] ?? i['data'] ?? ''}'),
                        );
                        final importo = _money(
                          double.tryParse(
                            '${i['Importo'] ?? i['importo'] ?? ''}',
                          ),
                        );
                        final metodo =
                            _cell(i['Metodo'] ?? i['metodo'] ?? i['Causale']);
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text('$data · $importo'),
                          subtitle: Text(metodo),
                        );
                      }),
                    const SizedBox(height: 12),
                    const Text(
                      'Fatture',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    if (d.fatture.isEmpty)
                      const Text(
                        'Nessuna fattura.',
                        style: TextStyle(color: Colors.black54),
                      )
                    else
                      ...d.fatture.take(20).map((f) {
                        final num = _cell(f['Numero'] ?? f['numero']);
                        final importo = _money(
                          double.tryParse(
                            '${f['Importo'] ?? f['importo'] ?? ''}',
                          ),
                        );
                        final pagato = _money(
                          double.tryParse(
                            '${f['Pagato'] ?? f['pagato'] ?? ''}',
                          ),
                        );
                        final scad = _when(
                          DateTime.tryParse(
                            '${f['DataScadenza'] ?? f['dataScadenza'] ?? f['DataFattura'] ?? ''}',
                          ),
                        );
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text('Fatt. $num · $importo'),
                          subtitle: Text('Scad. $scad · Pagato $pagato'),
                        );
                      }),
                  ],
                ),
              ),
              _accordion(
                id: _SchedaPratica.pianoRate,
                title: 'Piano rate',
                subtitle: d.rate.isEmpty ? '—' : '${d.rate.length} rate',
                child: d.rate.isEmpty
                    ? const Text(
                        'Nessuna rata.',
                        style: TextStyle(color: Colors.black54),
                      )
                    : Column(
                        children: d.rate.map((r) {
                          final n = _cell(r['NumeroRata'] ?? r['numeroRata']);
                          final imp = _money(
                            double.tryParse(
                              '${r['Importo'] ?? r['importo'] ?? ''}',
                            ),
                          );
                          final scad = _when(
                            DateTime.tryParse(
                              '${r['Scadenza'] ?? r['scadenza'] ?? ''}',
                            ),
                          );
                          final pagata = r['Pagata'] == true ||
                              r['pagata'] == true ||
                              r['Pagata'] == 1;
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              pagata
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: pagata ? Colors.green : Colors.black38,
                              size: 20,
                            ),
                            title: Text('Rata $n · $imp'),
                            subtitle: Text('Scadenza $scad'),
                          );
                        }).toList(),
                      ),
              ),
              _accordion(
                id: _SchedaPratica.note,
                title: 'Note',
                subtitle: '${d.note.length}',
                child: d.note.isEmpty
                    ? const Text(
                        'Nessuna nota.',
                        style: TextStyle(color: Colors.black54),
                      )
                    : Column(
                        children: d.note.map((n) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: n.importante
                                ? const Color(0xFFFFF8E1)
                                : null,
                            child: ListTile(
                              title: Text(
                                n.nota?.trim().isNotEmpty == true
                                    ? n.nota!
                                    : '—',
                              ),
                              subtitle: Text(
                                [
                                  if (n.fissata) 'Fissata',
                                  if (n.userName != null) n.userName!,
                                  if (n.createdAt != null)
                                    _whenFull(n.createdAt),
                                ].join(' · '),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
              _accordion(
                id: _SchedaPratica.documenti,
                title: 'Documenti',
                subtitle:
                    d.documenti.isEmpty ? '—' : '${d.documenti.length}',
                child: d.documenti.isEmpty
                    ? const Text(
                        'Nessun documento.',
                        style: TextStyle(color: Colors.black54),
                      )
                    : Column(
                        children: d.documenti.map((doc) {
                          final nome = _cell(
                            doc['Nome'] ?? doc['nome'] ?? doc['FileName'],
                          );
                          final tipo = _cell(doc['Tipo'] ?? doc['tipo']);
                          final created = _when(
                            DateTime.tryParse(
                              '${doc['CreatedAt'] ?? doc['createdAt'] ?? ''}',
                            ),
                          );
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.description_outlined),
                            title: Text(nome),
                            subtitle: Text('$tipo · $created'),
                          );
                        }).toList(),
                      ),
              ),
              _accordion(
                id: _SchedaPratica.lavorazione,
                title: 'Lavorazione',
                subtitle: 'Nota / scarico',
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _codiceScarico ?? '',
                      decoration: const InputDecoration(
                        labelText: 'Codice scarico',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('— Nessuno —'),
                        ),
                        ...kCodiciScaricoCreditCalc.entries.map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text('${e.key} · ${e.value}'),
                          ),
                        ),
                      ],
                      onChanged: _saving
                          ? null
                          : (v) => setState(
                                () => _codiceScarico =
                                    (v == null || v.isEmpty) ? null : v,
                              ),
                    ),
                    const SizedBox(height: 12),
                    VoiceNoteField(
                      controller: _notaCtrl,
                      labelText: 'Nota',
                      maxLines: 6,
                    ),
                    if (_formError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _formError!,
                        style: TextStyle(color: Colors.red.shade800),
                      ),
                    ],
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _saving ? null : _salva,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: const Color(0xFF00B0FF),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Salva nota / scarico'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _accordion({
    required _SchedaPratica id,
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    final open = _open == id;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            onTap: () => _toggle(id),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: subtitle == null || subtitle.isEmpty
                ? null
                : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Icon(open ? Icons.expand_less : Icons.expand_more),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: child,
            ),
            crossFadeState:
                open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String? v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              k,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              (v == null || v.trim().isEmpty) ? '—' : v,
              style: const TextStyle(fontWeight: FontWeight.w500, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
