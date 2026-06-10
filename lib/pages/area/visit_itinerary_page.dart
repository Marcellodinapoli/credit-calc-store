import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/dimensions.dart';
import '../../core/platform/mobile_app_feature.dart';
import '../../models/visit_stop.dart';
import '../../services/visit_itinerary/geocoding_service.dart';
import '../../services/visit_itinerary/route_optimizer.dart';
import '../../services/visit_itinerary/visit_itinerary_repository.dart';
import '../../services/visit_itinerary/visit_photo_text_extractor.dart';
import '../../widgets/mobile_only_feature_placeholder.dart';
import 'personal_area_shell.dart';

class VisitItineraryPage extends StatelessWidget {
  const VisitItineraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (!MobileAppFeature.isActive) {
      return PersonalAreaShell(
        pageTitle: 'Itinerario visite',
        body: const MobileOnlyFeaturePlaceholder(
          title: 'Itinerario visite — solo app mobile',
          description:
              'Pianifica le visite della giornata, importa i nominativi a mano '
              'o da foto e ottimizza il percorso più lineare per risparmiare '
              'tempo e carburante.\n\n'
              'Questa funzione è disponibile su CreditCalc per Android e iPhone. '
              'Apri l\'app sul telefono per usarla.',
          icon: Icons.route_outlined,
        ),
      );
    }

    return const _VisitItineraryMobilePage();
  }
}

class _VisitItineraryMobilePage extends StatefulWidget {
  const _VisitItineraryMobilePage();

  @override
  State<_VisitItineraryMobilePage> createState() =>
      _VisitItineraryMobilePageState();
}

class _VisitItineraryMobilePageState extends State<_VisitItineraryMobilePage> {
  final _repo = VisitItineraryRepository();
  final _geocoding = GeocodingService();
  bool _optimizing = false;
  double? _totalRouteKm;
  double? _savedKm;

  @override
  Widget build(BuildContext context) {
    final dateLabel = _formatToday();

    return PersonalAreaShell(
      pageTitle: 'Itinerario visite',
      body: StreamBuilder<List<VisitStop>>(
        stream: _repo.watchTodayStops(),
        builder: (context, snapshot) {
          final stops = snapshot.data ?? const [];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: Dimensions.scrollPadding(context).copyWith(bottom: 8),
                child: _SummaryCard(
                  dateLabel: dateLabel,
                  stopCount: stops.length,
                  totalKm: _totalRouteKm,
                  savedKm: _savedKm,
                ),
              ),
              if (stops.isEmpty)
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Aggiungi i nominativi da visitare oggi.\n'
                        'Poi ottimizza il percorso per il tragitto più lineare.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    padding: Dimensions.scrollPadding(context).copyWith(top: 0),
                    itemCount: stops.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final stop = stops[index];
                      return _StopTile(
                        index: index + 1,
                        stop: stop,
                        onVisitedChanged: (v) => _repo.updateStop(
                          stop.copyWith(visited: v),
                        ),
                        onDelete: () => _repo.deleteStop(stop.id),
                        onNavigate: () => _openMaps(stop),
                      );
                    },
                  ),
                ),
              _ActionBar(
                optimizing: _optimizing,
                canOptimize: stops.length >= 2,
                onAddManual: () => _showAddManualDialog(context),
                onAddPhoto: _importFromPhoto,
                onOptimize: () => _optimizeRoute(stops),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatToday() {
    final now = DateTime.now();
    const months = [
      'gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno',
      'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre',
    ];
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }

  Future<void> _showAddManualDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuova visita'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nominativo / ragione sociale',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressCtrl,
              decoration: const InputDecoration(
                labelText: 'Indirizzo completo',
                hintText: 'Via, civico, città',
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Aggiungi'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;
    if (nameCtrl.text.trim().isEmpty || addressCtrl.text.trim().isEmpty) {
      _snack('Compila nominativo e indirizzo.');
      return;
    }

    await _repo.addStop(
      clientName: nameCtrl.text,
      address: addressCtrl.text,
    );
  }

  Future<void> _importFromPhoto() async {
    final camera = await Permission.camera.request();
    if (!camera.isGranted) {
      _snack('Serve il permesso fotocamera per importare da foto.');
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Scatta foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Scegli da galleria'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 85);
    if (file == null || !mounted) return;

    _snack('Lettura testo in corso…');
    final lines = await extractVisitLinesFromImage(file.path);
    if (!mounted) return;

    if (lines.isEmpty) {
      _snack('Nessun testo riconosciuto nella foto.');
      return;
    }

    await _showLinesImportDialog(lines);
  }

  Future<void> _showLinesImportDialog(List<String> lines) async {
    final selected = List<bool>.filled(lines.length, true);

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Righe riconosciute'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: lines.length,
              itemBuilder: (_, i) => CheckboxListTile(
                value: selected[i],
                onChanged: (v) => setLocal(() => selected[i] = v ?? false),
                title: Text(lines[i]),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                for (var i = 0; i < lines.length; i++) {
                  if (!selected[i]) continue;
                  final line = lines[i];
                  if (!mounted) return;
                  await _confirmLineImport(line);
                }
              },
              child: const Text('Importa selezionate'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLineImport(String line) async {
    final nameCtrl = TextEditingController(text: line);
    final addressCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Conferma visita'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nominativo'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressCtrl,
              decoration: const InputDecoration(
                labelText: 'Indirizzo (obbligatorio per il percorso)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Salta'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Aggiungi'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;
    if (nameCtrl.text.trim().isEmpty || addressCtrl.text.trim().isEmpty) return;

    await _repo.addStop(
      clientName: nameCtrl.text,
      address: addressCtrl.text,
    );
  }

  Future<void> _optimizeRoute(List<VisitStop> stops) async {
    if (stops.length < 2) return;

    setState(() => _optimizing = true);
    try {
      final locationOk = await _ensureLocation();
      if (!locationOk || !mounted) {
        _snack('Posizione non disponibile: impossibile ottimizzare.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      final start = LatLng(position.latitude, position.longitude);

      _snack('Geocoding indirizzi…');
      final geocoded = <VisitStop>[];
      for (final stop in stops) {
        if (!mounted) return;
        var updated = stop;
        if (!stop.hasCoordinates) {
          final coords = await _geocoding.geocodeAddress(stop.address);
          if (coords != null) {
            updated = stop.copyWith(
              latitude: coords.lat,
              longitude: coords.lng,
            );
          }
          await Future<void>.delayed(const Duration(milliseconds: 1100));
        }
        geocoded.add(updated);
      }

      final withCoords = geocoded.where((s) => s.hasCoordinates).toList();
      if (withCoords.length < 2) {
        _snack(
          'Servono almeno 2 indirizzi validi per ottimizzare il percorso.',
        );
        return;
      }

      final points = withCoords
          .map((s) => LatLng(s.latitude!, s.longitude!))
          .toList();

      final originalOrder = List<int>.generate(points.length, (i) => i);
      final originalKm = RouteOptimizer.totalDistanceKm(
        start: start,
        stops: points,
        order: originalOrder,
      );

      final optimizedIndices = RouteOptimizer.optimize(
        start: start,
        stops: points,
      );

      final optimizedKm = RouteOptimizer.totalDistanceKm(
        start: start,
        stops: points,
        order: optimizedIndices,
      );

      final ordered = [
        for (final i in optimizedIndices) withCoords[i],
      ];

      await _repo.saveOptimizedOrder(ordered);

      if (!mounted) return;
      setState(() {
        _totalRouteKm = optimizedKm;
        _savedKm = (originalKm - optimizedKm).clamp(0, double.infinity);
      });

      _snack(
        'Percorso ottimizzato: ${optimizedKm.toStringAsFixed(1)} km'
        '${_savedKm! > 0.1 ? ' (risparmio ~${_savedKm!.toStringAsFixed(1)} km)' : ''}.',
      );
    } finally {
      if (mounted) setState(() => _optimizing = false);
    }
  }

  Future<bool> _ensureLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return false;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<void> _openMaps(VisitStop stop) async {
    final Uri uri;
    if (stop.hasCoordinates) {
      uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination='
        '${stop.latitude},${stop.longitude}',
      );
    } else {
      uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination='
        '${Uri.encodeComponent(stop.address)}',
      );
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.dateLabel,
    required this.stopCount,
    this.totalKm,
    this.savedKm,
  });

  final String dateLabel;
  final int stopCount;
  final double? totalKm;
  final double? savedKm;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.green.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Visite del $dateLabel',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              stopCount == 0
                  ? 'Nessuna visita inserita.'
                  : '$stopCount ${stopCount == 1 ? 'tappa' : 'tappe'} in programma.',
              style: TextStyle(color: Colors.green.shade900),
            ),
            if (totalKm != null) ...[
              const SizedBox(height: 4),
              Text(
                'Percorso stimato: ${totalKm!.toStringAsFixed(1)} km'
                '${savedKm != null && savedKm! > 0.1 ? ' · risparmio ~${savedKm!.toStringAsFixed(1)} km' : ''}',
                style: TextStyle(
                  color: Colors.green.shade800,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              'Ottimizza l\'ordine delle visite per il tragitto più lineare '
              'e ridurre tempo e carburante.',
              style: TextStyle(fontSize: 13, color: Colors.green.shade900),
            ),
          ],
        ),
      ),
    );
  }
}

class _StopTile extends StatelessWidget {
  const _StopTile({
    required this.index,
    required this.stop,
    required this.onVisitedChanged,
    required this.onDelete,
    required this.onNavigate,
  });

  final int index;
  final VisitStop stop;
  final ValueChanged<bool> onVisitedChanged;
  final VoidCallback onDelete;
  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: stop.visited ? Colors.grey : Colors.teal.shade100,
          foregroundColor: stop.visited ? Colors.white : Colors.teal.shade900,
          child: Text('$index'),
        ),
        title: Text(
          stop.clientName,
          style: TextStyle(
            decoration: stop.visited ? TextDecoration.lineThrough : null,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(stop.address),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'nav':
                onNavigate();
              case 'delete':
                onDelete();
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'nav', child: Text('Apri navigazione')),
            PopupMenuItem(value: 'delete', child: Text('Elimina')),
          ],
        ),
        onTap: () => onVisitedChanged(!stop.visited),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.optimizing,
    required this.canOptimize,
    required this.onAddManual,
    required this.onAddPhoto,
    required this.onOptimize,
  });

  final bool optimizing;
  final bool canOptimize;
  final VoidCallback onAddManual;
  final VoidCallback onAddPhoto;
  final VoidCallback onOptimize;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onAddManual,
                      icon: const Icon(Icons.person_add_outlined),
                      label: const Text('Aggiungi'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onAddPhoto,
                      icon: const Icon(Icons.document_scanner_outlined),
                      label: const Text('Da foto'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: optimizing || !canOptimize ? null : onOptimize,
                icon: optimizing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.route_outlined),
                label: Text(
                  optimizing
                      ? 'Ottimizzazione…'
                      : 'Ottimizza percorso (più lineare)',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
