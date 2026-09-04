import 'package:flutter/material.dart';

import '../../../config/gestionale_connector_config.dart';
import '../../../services/creditcalc_gestionale_service.dart';
import 'affido_pratiche_page.dart';
import 'itinerary_page_shell.dart';

/// Collegamento account Credixa (consulente esterno abilitato da Admin).
class AffidoLinkPage extends StatefulWidget {
  const AffidoLinkPage({super.key});

  @override
  State<AffidoLinkPage> createState() => _AffidoLinkPageState();
}

class _AffidoLinkPageState extends State<AffidoLinkPage> {
  final _tenantCtrl = TextEditingController(
    text: GestionaleConnectorConfig.defaultTenantSlug,
  );
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _svc = CreditCalcGestionaleService.instance;

  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final existing = await _svc.loadSavedSession();
    if (!mounted || existing == null) return;
    try {
      await _svc.ensureSession();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AffidoPratichePage()),
      );
    } catch (_) {
      await _svc.clearSession();
    }
  }

  @override
  void dispose() {
    _tenantCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _svc.login(
        tenantSlug: _tenantCtrl.text,
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AffidoPratichePage()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
      return;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    const shell = ItineraryPageShell();
    return shell.secondary(
      pageTitle: 'Pratiche in affido',
      body: ListView(
        padding: ItineraryPageShell.listPadding(context),
        children: [
          const Text(
            'Collega l’account gestionale solo se il login dell’app non ha '
            'già autorizzato le pratiche (stessa email/password del consulente '
            'abilitato da Admin). Di solito basta accedere all’app una volta.',
            style: TextStyle(color: Colors.black54, height: 1.45),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _tenantCtrl,
            decoration: const InputDecoration(
              labelText: 'Codice azienda',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailCtrl,
            decoration: const InputDecoration(
              labelText: 'Email gestionale',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Password',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onSubmitted: (_) => _loading ? null : _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Colors.red.shade800, height: 1.35),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _loading ? null : _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: const Color(0xFF00B0FF),
            ),
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Collega e continua'),
          ),
          const SizedBox(height: 8),
          Text(
            'Connettore: ${GestionaleConnectorConfig.baseUrl}',
            style: const TextStyle(fontSize: 11, color: Colors.black38),
          ),
        ],
      ),
    );
  }
}
