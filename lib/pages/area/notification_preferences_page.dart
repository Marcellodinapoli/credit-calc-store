import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/dimensions.dart';
import '../../services/product_notifications_service.dart';
import 'personal_area_shell.dart';

/// Preferenze notifiche di prodotto nell'area personale (CreditArea).
class NotificationPreferencesPage extends StatefulWidget {
  const NotificationPreferencesPage({super.key});

  @override
  State<NotificationPreferencesPage> createState() =>
      _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState
    extends State<NotificationPreferencesPage> {
  bool _loading = true;
  bool _enabled = false;
  bool _saving = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = _uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    final enabled = await ProductNotificationsService.loadEnabled(uid);
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _loading = false;
    });
  }

  Future<void> _onChanged(bool value) async {
    final uid = _uid;
    if (uid == null || _saving) return;

    setState(() {
      _saving = true;
      _enabled = value;
    });

    final result = await ProductNotificationsService.setEnabled(
      uid: uid,
      enabled: value,
    );

    if (!mounted) return;

    setState(() => _saving = false);

    if (!result.success) {
      setState(() => _enabled = !value);
      _showSnack('Non è stato possibile salvare la preferenza. Riprova.');
      return;
    }

    if (value) {
      if (result.permissionIssue != null) {
        setState(() => _enabled = false);
        _showSnack(result.permissionIssue!);
      } else if (result.tokenRegistered) {
        _showSnack('Notifiche attivate su questo dispositivo.');
      } else {
        _showSnack(
          'Preferenza salvata. Se richiesto, consenti le notifiche sul dispositivo.',
        );
      }
    } else {
      _showSnack('Notifiche disattivate.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PersonalAreaShell(
      pageTitle: 'Aggiornamenti',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: Dimensions.scrollPadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scegli se ricevere avvisi su novità utili della piattaforma. '
                    'Non inviamo comunicazioni di marketing.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: SwitchListTile(
                      title: const Text(
                        'Ricevi notifiche',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Attiva o disattiva in qualsiasi momento.',
                      ),
                      value: _enabled,
                      onChanged: _uid == null || _saving ? null : _onChanged,
                    ),
                  ),
                  if (_saving) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'Di cosa riceverai avviso',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _bullet(
                    context,
                    'nuove offerte di lavoro pubblicate su CreditJob;',
                  ),
                  _bullet(
                    context,
                    'nuovi corsi o percorsi formativi su CreditForm;',
                  ),
                  _bullet(
                    context,
                    'nuove funzioni o aggiornamenti importanti della piattaforma.',
                  ),
                  const SizedBox(height: 24),
                  _infoBox(
                    context,
                    icon: Icons.campaign_outlined,
                    title: 'Nessun marketing',
                    text:
                        'Queste notifiche non riguardano promozioni, newsletter '
                        'commerciali o messaggi pubblicitari. Servono solo per '
                        'informarti su contenuti e servizi già presenti in '
                        'CreditCore.',
                  ),
                  const SizedBox(height: 16),
                  _infoBox(
                    context,
                    icon: Icons.devices_outlined,
                    title: 'Dispositivo',
                    text:
                        'Attivando l\'opzione, il sistema può chiederti il '
                        'consenso alle notifiche push. La scelta si applica al '
                        'dispositivo che stai usando.',
                  ),
                ],
              ),
            ),
    );
  }

  Widget _bullet(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _infoBox(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String text,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(text, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
