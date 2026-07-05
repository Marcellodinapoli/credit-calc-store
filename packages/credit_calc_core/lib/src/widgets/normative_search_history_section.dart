import 'package:flutter/material.dart';

import '../ai/normative_search_log_service.dart';

String _formatDateTime(DateTime? value) {
  if (value == null) return '—';
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year.toString();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month/$year  $hour:$minute';
}

/// Elenco ricerche normative effettuate dagli utenti (solo admin BK).
class NormativeSearchHistorySection extends StatelessWidget {
  const NormativeSearchHistorySection({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ricerche effettuate',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Ultime domande inviate da CreditCalc Store → Sviluppa → '
              'Ricerca normativa.',
              style: TextStyle(color: Colors.grey.shade700, height: 1.4),
            ),
            const SizedBox(height: 16),
            StreamBuilder<List<NormativeSearchLogEntry>>(
              stream: NormativeSearchLogService.watchRecent(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Impossibile caricare lo storico: ${snapshot.error}',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  );
                }

                final entries = snapshot.data ?? const [];
                if (entries.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Nessuna ricerca registrata.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return _NormativeSearchLogTile(entry: entry);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NormativeSearchLogTile extends StatefulWidget {
  const _NormativeSearchLogTile({required this.entry});

  final NormativeSearchLogEntry entry;

  @override
  State<_NormativeSearchLogTile> createState() =>
      _NormativeSearchLogTileState();
}

class _NormativeSearchLogTileState extends State<_NormativeSearchLogTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final answer = entry.answer.trim().isNotEmpty
        ? entry.answer
        : entry.answerPreview;

    return InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    entry.question,
                    maxLines: _expanded ? null : 2,
                    overflow: _expanded ? null : TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  _formatDateTime(entry.createdAt),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  entry.userLabel,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 12),
              Text(
                answer,
                style: const TextStyle(height: 1.45),
              ),
            ] else if (entry.answerPreview.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                entry.answerPreview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey.shade800,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
