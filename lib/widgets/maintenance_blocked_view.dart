import 'package:flutter/material.dart';

class MaintenanceBlockedView extends StatelessWidget {
  final String sectionName;

  const MaintenanceBlockedView({
    super.key,
    required this.sectionName,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.construction_rounded,
              size: 56,
              color: Colors.orange.shade700,
            ),
            const SizedBox(height: 16),
            Text(
              'Sezione in manutenzione',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '$sectionName non è al momento disponibile. '
              'Riprova più tardi.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
