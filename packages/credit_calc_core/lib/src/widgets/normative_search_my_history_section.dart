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

/// Storico personale ricerche normative (solo utente corrente).
class NormativeSearchMyHistorySection extends StatelessWidget {
  const NormativeSearchMyHistorySection({
    super.key,
    this.onSelectQuestion,
  });

  final ValueChanged<String>? onSelectQuestion;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NormativeSearchLogEntry>>(
      stream: NormativeSearchLogService.watchMine(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SizedBox.shrink();
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Storico non disponibile.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          );
        }

        final entries = snapshot.data ?? const [];
        if (entries.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          margin: EdgeInsets.zero,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: false,
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              title: Text(
                'Le tue ricerche precedenti (${entries.length})',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              subtitle: Text(
                'Rivedi le risposte già ottenute ed evita domande duplicate.',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      // Elenco più recenti in alto: numero cronologico (1 = prima ricerca).
                      final number = entries.length - index;
                      return _NormativeSearchMyLogTile(
                        number: number,
                        entry: entry,
                        onSelectQuestion: onSelectQuestion,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NormativeSearchMyLogTile extends StatefulWidget {
  const _NormativeSearchMyLogTile({
    required this.number,
    required this.entry,
    this.onSelectQuestion,
  });

  final int number;
  final NormativeSearchLogEntry entry;
  final ValueChanged<String>? onSelectQuestion;

  @override
  State<_NormativeSearchMyLogTile> createState() =>
      _NormativeSearchMyLogTileState();
}

class _NormativeSearchMyLogTileState extends State<_NormativeSearchMyLogTile> {
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.number}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(width: 8),
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
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _formatDateTime(entry.createdAt),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            if (_expanded) ...[
              const SizedBox(height: 10),
              Text(answer, style: const TextStyle(height: 1.45)),
              if (widget.onSelectQuestion != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => widget.onSelectQuestion!(entry.question),
                    child: const Text('Usa di nuovo questa domanda'),
                  ),
                ),
              ],
            ] else if (entry.answerPreview.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                entry.answerPreview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade800, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
