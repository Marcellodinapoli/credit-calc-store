import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/itinerary_notifications_service.dart';
import '../services/product_notifications_service.dart';

class ItineraryNotificationsCard extends StatefulWidget {
  const ItineraryNotificationsCard({super.key});

  @override
  State<ItineraryNotificationsCard> createState() =>
      _ItineraryNotificationsCardState();
}

class _ItineraryNotificationsCardState extends State<ItineraryNotificationsCard> {
  bool _loading = true;
  bool _enabled = false;
  bool _productEnabled = false;
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

    final productEnabled =
        await ProductNotificationsService.loadEnabled(uid);
    final enabled = await ItineraryNotificationsService.loadEnabled(uid);

    if (!mounted) return;
    setState(() {
      _productEnabled = productEnabled;
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

    await ItineraryNotificationsService.setEnabled(uid: uid, enabled: value);

    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value
              ? 'Promemoria itinerario attivati su questo dispositivo.'
              : 'Promemoria itinerario disattivati.',
        ),
      ),
    );
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

    return Card(
      child: SwitchListTile(
        title: const Text(
          'Notifiche itinerario',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          !_productEnabled
              ? 'Attiva prima le notifiche in Area personale → Notifiche.'
              : 'Promemoria programmati e avviso 30 min prima delle visite.',
        ),
        value: _enabled,
        onChanged: _productEnabled && !_saving ? _onChanged : null,
      ),
    );
  }
}
