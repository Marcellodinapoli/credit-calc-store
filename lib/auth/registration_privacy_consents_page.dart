import 'package:flutter/material.dart';

import '../core/theme/app_surface_theme.dart';
import 'registration_consents_service.dart';

abstract final class _RegistrationLegalTheme {
  static const accent = Color(0xFF0A66C2);
  static const body = AppSurfaceTheme.pageMuted;
}

class RegistrationPrivacyConsentsPage extends StatefulWidget {
  const RegistrationPrivacyConsentsPage({
    super.key,
    this.text,
    this.version,
    this.mandatory = false,
  });

  final String? text;
  final String? version;
  final bool mandatory;

  @override
  State<RegistrationPrivacyConsentsPage> createState() =>
      _RegistrationPrivacyConsentsPageState();
}

class _RegistrationPrivacyConsentsPageState
    extends State<RegistrationPrivacyConsentsPage> {
  final _scrollController = ScrollController();

  bool _loading = true;
  bool _reachedBottom = false;
  bool _accepted = false;
  String? _loadError;
  String _text = '';
  String _version = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }

    if (widget.text != null && widget.version != null) {
      _text = widget.text!;
      _version = widget.version!;
      if (mounted) setState(() => _loading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
      return;
    }

    try {
      final document = await RegistrationConsentsService.loadCurrent();
      if (!mounted) return;

      if (document == null) {
        setState(() {
          _loading = false;
          _loadError =
              'Impossibile caricare l\'informativa privacy e consensi. '
              'Verifica la connessione a Internet e riprova.';
        });
        return;
      }

      setState(() {
        _text = document.text;
        _version = document.version;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError =
            'Errore durante il caricamento. Verifica la connessione e riprova.';
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final atBottom =
        position.maxScrollExtent <= 0 ||
        position.pixels >= position.maxScrollExtent - 24;

    if (atBottom != _reachedBottom) {
      setState(() => _reachedBottom = atBottom);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.mandatory,
      child: Scaffold(
        backgroundColor: _RegistrationLegalTheme.body,
        appBar: AppBar(
          title: Text(
            _version.isEmpty
                ? 'Privacy e consensi'
                : 'Privacy e consensi (v$_version)',
          ),
          backgroundColor: AppSurfaceTheme.page,
          foregroundColor: const Color(0xFF111111),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: !widget.mandatory,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cloud_off_outlined,
                            size: 48,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _loadError!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade800,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: _loadDocument,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Riprova'),
                            style: FilledButton.styleFrom(
                              backgroundColor: _RegistrationLegalTheme.accent,
                            ),
                          ),
                          if (!widget.mandatory) ...[
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Torna alla registrazione'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : Column(
                children: [
                  Expanded(
                    child: Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Leggi l\'informativa completa. Per accettare, scorri fino in fondo.',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _text,
                              style: const TextStyle(fontSize: 15, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Material(
                    elevation: 8,
                    color: AppSurfaceTheme.page,
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!_reachedBottom)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  'Scorri fino alla fine del documento per abilitare il consenso.',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            CheckboxListTile(
                              value: _accepted,
                              onChanged: _reachedBottom
                                  ? (value) => setState(
                                        () => _accepted = value ?? false,
                                      )
                                  : null,
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Ho letto e accetto l\'informativa sulla privacy e i consensi',
                                style: TextStyle(fontSize: 14, height: 1.35),
                              ),
                            ),
                            if (widget.mandatory) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Devi accettare le nuove condizioni per continuare.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            FilledButton(
                              onPressed: _accepted
                                  ? () => Navigator.pop(context, _version)
                                  : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: _RegistrationLegalTheme.accent,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: Text(
                                widget.mandatory
                                    ? 'Ho preso visione e accetto'
                                    : 'Conferma e torna alla registrazione',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
