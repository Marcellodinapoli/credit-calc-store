import 'package:flutter/material.dart';

import '../core/euro_format.dart';
import '../core/theme/app_action_styles.dart';
import '../core/theme/app_form_fields.dart';

/// Come registrare gli incassi quando ci sono rate in mesi successivi a quello corrente.
enum CommissionExportDateMode {
  /// Un unico incasso nella data scelta nel calendario.
  singleDate,

  /// Un incasso per ogni data prevista dal piano.
  respectSchedule,
}

class CommissionExportScheduleLine {
  final DateTime date;
  final double amount;
  final String? label;

  const CommissionExportScheduleLine({
    required this.date,
    required this.amount,
    this.label,
  });
}

class CommissionExportDialogResult {
  final String companyName;
  final DateTime collectionDate;
  final CommissionExportDateMode dateMode;

  const CommissionExportDialogResult({
    required this.companyName,
    required this.collectionDate,
    required this.dateMode,
  });
}

String formatCommissionExportDate(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d/$m/${date.year}';
}

bool isPaymentAfterCurrentMonth(DateTime date) {
  final now = DateTime.now();
  return date.year > now.year ||
      (date.year == now.year && date.month > now.month);
}

/// Popup condiviso (piani di rientro, saldo e stralcio): ragione sociale e data incasso.
Future<CommissionExportDialogResult?> showCommissionExportDialog({
  required BuildContext context,
  required String description,
  required bool hasPaymentsAfterCurrentMonth,
  List<CommissionExportScheduleLine> scheduledPayments = const [],
  DateTime? initialCollectionDate,
}) {
  final companyCtrl = TextEditingController();
  var collectionDate = DateTime(
    (initialCollectionDate ?? DateTime.now()).year,
    (initialCollectionDate ?? DateTime.now()).month,
    (initialCollectionDate ?? DateTime.now()).day,
  );
  var dateMode = CommissionExportDateMode.singleDate;

  final showScheduleChoice = hasPaymentsAfterCurrentMonth &&
      scheduledPayments.isNotEmpty;

  CommissionExportDialogResult buildResult(String name) {
    return CommissionExportDialogResult(
      companyName: name,
      collectionDate: collectionDate,
      dateMode: showScheduleChoice
          ? dateMode
          : CommissionExportDateMode.singleDate,
    );
  }

  return showDialog<CommissionExportDialogResult>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final useScheduleList = showScheduleChoice &&
              dateMode == CommissionExportDateMode.respectSchedule;

          return AlertDialog(
            title: const Text('Registra incassi in provvigioni'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    if (showScheduleChoice) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Alcune rate hanno data successiva al mese in corso. '
                        'Come vuoi registrare gli incassi?',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      RadioListTile<CommissionExportDateMode>(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Unico incasso nella data scelta',
                          style: TextStyle(fontSize: 13),
                        ),
                        subtitle: Text(
                          'Tutto l\'importo nella data del calendario sotto.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        value: CommissionExportDateMode.singleDate,
                        groupValue: dateMode,
                        onChanged: (v) {
                          if (v == null) return;
                          setDialogState(() => dateMode = v);
                        },
                      ),
                      RadioListTile<CommissionExportDateMode>(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Rispetta le date dei pagamenti previsti',
                          style: TextStyle(fontSize: 13),
                        ),
                        subtitle: Text(
                          'Un incasso per ogni rata, anche nei mesi successivi.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        value: CommissionExportDateMode.respectSchedule,
                        groupValue: dateMode,
                        onChanged: (v) {
                          if (v == null) return;
                          setDialogState(() => dateMode = v);
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (useScheduleList)
                      _scheduledPaymentsList(scheduledPayments)
                    else ...[
                      Text(
                        'Data incasso',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: dialogContext,
                            initialDate: collectionDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setDialogState(
                              () => collectionDate = DateTime(
                                picked.year,
                                picked.month,
                                picked.day,
                              ),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: InputDecorator(
                          decoration:
                              appFormFieldDecoration('Seleziona data'),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  formatCommissionExportDate(collectionDate),
                                ),
                              ),
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 20,
                                color: Colors.grey.shade600,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: companyCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: appFormFieldDecoration(
                        'Ragione sociale debitore',
                      ).copyWith(
                        hintText: 'Nome committente / debitore',
                      ),
                      autofocus: !useScheduleList,
                      onSubmitted: (_) {
                        final name = companyCtrl.text.trim();
                        if (name.isEmpty) return;
                        Navigator.pop(dialogContext, buildResult(name));
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                style: AppActionStyles.cancelText,
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () {
                  final name = companyCtrl.text.trim();
                  if (name.isEmpty) return;
                  Navigator.pop(dialogContext, buildResult(name));
                },
                child: const Text('Conferma'),
              ),
            ],
          );
        },
      );
    },
  ).whenComplete(companyCtrl.dispose);
}

Widget _scheduledPaymentsList(List<CommissionExportScheduleLine> lines) {
  final total = lines.fold<double>(0, (sum, line) => sum + line.amount);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Rate da registrare',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade800,
        ),
      ),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          children: [
            for (var i = 0; i < lines.length; i++) ...[
              if (i > 0) Divider(height: 1, color: Colors.grey.shade300),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        lines[i].label ?? 'Rata ${i + 1}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatCommissionExportDate(lines[i].date),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            EuroFormat.format(lines[i].amount),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Divider(height: 1, color: Colors.grey.shade300),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Totale',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    EuroFormat.format(total),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Verrà creato un incasso in provvigioni per ogni rata alle date indicate.',
        style: TextStyle(
          fontSize: 12,
          height: 1.4,
          color: Colors.grey.shade600,
        ),
      ),
    ],
  );
}
