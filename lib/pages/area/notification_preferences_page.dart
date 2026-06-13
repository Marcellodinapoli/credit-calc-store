import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/dimensions.dart';
import '../../services/field_reminder_notification_service.dart';
import '../../services/itinerary_notifications_service.dart';
import '../../services/location_consent_service.dart';
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
  bool _itineraryEnabled = false;
  bool _saving = false;
  bool _savingItinerary = false;

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
    final itineraryEnabled =
        await ItineraryNotificationsService.loadEnabled(uid);
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _itineraryEnabled = itineraryEnabled;
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
      _showSnack('Notifiche attivate.');
    } else {
      await ItineraryNotificationsService.setEnabled(uid: uid, enabled: false);
      await LocationConsentService.setEnabled(uid: uid, enabled: false);
      if (!mounted) return;
      setState(() => _itineraryEnabled = false);
      _showSnack('Notifiche disattivate.');
    }
  }

  Future<void> _onItineraryChanged(bool value) async {
    final uid = _uid;
    if (uid == null || _savingItinerary || !_enabled) return;

    setState(() {
      _savingItinerary = true;
      _itineraryEnabled = value;
    });

    await ItineraryNotificationsService.setEnabled(uid: uid, enabled: value);
    await LocationConsentService.setEnabled(uid: uid, enabled: value);
    if (value) {
      await FieldReminderNotificationService.syncAllForCurrentUser();
    }

    if (!mounted) return;
    setState(() => _savingItinerary = false);
    _showSnack(
      value
          ? 'Promemoria itinerario e uso posizione attivati.'
          : 'Promemoria itinerario e uso posizione disattivati.',
    );
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
      pageTitle: 'Notifiche',
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
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text(
                            'Ricevi notifiche',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text(
                            'Attiva o disattiva in qualsiasi momento.',
                          ),
                          value: _enabled,
                          onChanged:
                              _uid == null || _saving ? null : _onChanged,
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: const Text('Itinerario sul territorio'),
                          subtitle: const Text(
                            'Promemoria programmati, avviso 30 min prima delle '
                            'visite e uso della posizione per i percorsi.',
                          ),
                          value: _itineraryEnabled,
                          onChanged: _uid == null ||
                                  _savingItinerary ||
                                  !_enabled
                              ? null
                              : _onItineraryChanged,
                        ),
                      ],
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
                    'nuove funzioni o aggiornamenti importanti della piattaforma;',
                  ),
                  _bullet(
                    context,
                    'promemoria itinerario e avvisi pre-visita (se attivati).',
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
                    icon: Icons.verified_user_outlined,
                    title: 'Consenso da questa pagina',
                    text:
                        'Attivando le opzioni confermi di voler ricevere gli '
                        'avvisi indicati e, per l\'itinerario, di autorizzare '
                        'l\'uso della posizione per i percorsi. La scelta resta '
                        'valida su questo dispositivo finché non la modifichi.',
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
