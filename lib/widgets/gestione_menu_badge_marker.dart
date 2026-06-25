import 'package:flutter/material.dart';

import '../services/gestione_menu_badge_service.dart';

/// Segna come visualizzata la voce Gestione corrente all'apertura pagina.
class GestioneMenuBadgeMarker extends StatefulWidget {
  const GestioneMenuBadgeMarker({
    super.key,
    required this.badgeKey,
    required this.child,
  });

  final GestioneMenuBadgeKey? badgeKey;
  final Widget child;

  @override
  State<GestioneMenuBadgeMarker> createState() =>
      _GestioneMenuBadgeMarkerState();
}

class _GestioneMenuBadgeMarkerState extends State<GestioneMenuBadgeMarker> {
  @override
  void initState() {
    super.initState();
    _markIfNeeded();
  }

  @override
  void didUpdateWidget(covariant GestioneMenuBadgeMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.badgeKey != widget.badgeKey) {
      _markIfNeeded();
    }
  }

  void _markIfNeeded() {
    final key = widget.badgeKey;
    if (key == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GestioneMenuBadgeService.markViewed(key);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
