import 'package:flutter/material.dart';

import '../core/theme/app_card_theme.dart';

/// Dettagli pratica (campi `practiceData` da Firestore) per roleplay.
class RoleplayPracticeDetailsPanel extends StatelessWidget {
  const RoleplayPracticeDetailsPanel({
    super.key,
    required this.title,
    required this.practiceData,
    this.compact = false,
  });

  final String title;
  final List<dynamic> practiceData;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppCardTheme.surface,
      elevation: AppCardTheme.elevation,
      shape: AppCardTheme.shape,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(compact ? 14 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: compact ? 15 : 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            if (practiceData.isNotEmpty) ...[
              SizedBox(height: compact ? 10 : 12),
              for (final item in practiceData)
                if (item is Map) ...[
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${item['label'] ?? ''}: ',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                        TextSpan(
                          text: '${item['value'] ?? ''}',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
            ],
          ],
        ),
      ),
    );
  }
}
