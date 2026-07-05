import 'package:flutter/material.dart';

/// Disabilitato: il blocco è a livello app intera (AppSessionGate).
class SectionOccupancyScope extends StatefulWidget {
  const SectionOccupancyScope({
    super.key,
    required this.sectionKey,
    required this.child,
  });

  final String sectionKey;
  final Widget child;

  @override
  State<SectionOccupancyScope> createState() => _SectionOccupancyScopeState();
}

class _SectionOccupancyScopeState extends State<SectionOccupancyScope> {
  @override
  Widget build(BuildContext context) => widget.child;
}

/// Apre una pagina senza blocco per sezione.
Future<T?> pushSectionOccupancy<T>(
  BuildContext context, {
  required String sectionKey,
  required Widget child,
  bool rootNavigator = false,
}) {
  return Navigator.of(context, rootNavigator: rootNavigator).push<T>(
    MaterialPageRoute(builder: (_) => child),
  );
}
