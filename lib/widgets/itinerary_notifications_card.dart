import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/itinerary_notifications_service.dart';
import '../services/location_consent_service.dart';
import '../services/notification_preferences_notifier.dart';
import '../services/product_notifications_service.dart';

class ItineraryNotificationsCard extends StatefulWidget {
  const ItineraryNotificationsCard({super.key});

  @override
  State<ItineraryNotificationsCard> createState() =>
      _ItineraryNotificationsCardState();
}

class _ItineraryNotificationsCardState extends State<ItineraryNotificationsCard> {
  bool _loading = true;
  bool _itineraryEnabled = false;
  bool _productEnabled = false;
  bool _saving = false;
  StreamSubscription<void>? _prefsSub;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _prefsSub = NotificationPreferencesNotifier.instance.changes.listen((_) {
      _load();
    });
    _load();
  }

  @override
  void dispose() {
    _prefsSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = _uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final productEnabled =
        await ProductNotificationsService.loadEnabled(uid);
    final doc = await ItineraryNotificationsService.loadItineraryField(uid);

    if (!mounted) return;
    setState(() {
      _productEnabled = productEnabled;
      _itineraryEnabled = doc;
      _loading = false;
    });
  }

  Future<void> _onChanged(bool value) async {
    final uid = _uid;
    if (uid == null || _saving || !_productEnabled) return;

    setState(() {
      _saving = true;
      _itineraryEnabled = value;
    });

    await ItineraryNotificationsService.setEnabled(uid: uid, enabled: value);
    await LocationConsentService.setEnabled(uid: uid, enabled: value);

    if (!mounted) return;
    setState(() => _saving = false);

    NotificationPreferencesNotifier.instance.notifyChanged();

    if (value) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Promemoria itinerario attivati su questo dispositivo.',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Promemoria itinerario disattivati.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: LinearProgressIndicator(),
        ),
      );
    }

    if (_itineraryEnabled) {
      return const SizedBox.shrink();
    }

    return Card(
      child: SwitchListTile(
        title: const Text(
          'Notifiche itinerario',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          !_productEnabled
              ? 'Attiva prima «Ricevi notifiche» in Area personale → Notifiche.'
              : 'Promemoria programmati e avviso 30 min prima delle visite.',
        ),
        value: _itineraryEnabled,
        onChanged: _productEnabled && !_saving ? _onChanged : null,
      ),
    );
  }
}

/// Messaggio informativo se le notifiche itinerario non sono ancora attivate.
class ItineraryNotificationsConsentHint extends StatefulWidget {
  const ItineraryNotificationsConsentHint({super.key});

  @override
  State<ItineraryNotificationsConsentHint> createState() =>
      _ItineraryNotificationsConsentHintState();
}

class _ItineraryNotificationsConsentHintState
    extends State<ItineraryNotificationsConsentHint> {
  bool _loading = true;
  bool _enabled = false;
  StreamSubscription<void>? _prefsSub;

  @override
  void initState() {
    super.initState();
    _prefsSub = NotificationPreferencesNotifier.instance.changes.listen((_) {
      _load();
    });
    _load();
  }

  @override
  void dispose() {
    _prefsSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final enabled = await ItineraryNotificationsService.loadEnabled(uid);
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _enabled) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Attiva le notifiche itinerario da Area personale → Notifiche '
          'per ricevere promemoria programmati e avvisi 30 min prima delle visite.',
          style: TextStyle(color: Colors.black.withValues(alpha: 0.54)),
        ),
      ),
    );
  }
}
