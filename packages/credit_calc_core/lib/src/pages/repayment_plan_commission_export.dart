import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_action_styles.dart';
import 'commission_export_dialog.dart';
import 'commission_payment_resolver.dart';

/// Scelta nel dialog dopo «Annulla» con incassi registrati in sessione.
enum PlanCancelWithCommissionsAction {
  stay,
  deleteAndStay,
  exitKeepCommissions,
  exitDeleteCommissions,
}

/// Chiede come gestire gli incassi registrati in questa sessione.
Future<PlanCancelWithCommissionsAction?> showPlanCancelWithCommissionsDialog(
  BuildContext context, {
  required int registeredCount,
}) {
  final label =
      registeredCount == 1 ? '1 incasso registrato' : '$registeredCount incassi registrati';

  return showDialog<PlanCancelWithCommissionsAction>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Annulla sviluppo piano'),
      content: Text(
        'In questa sessione hai $label in provvigioni.\n\n'
        'Puoi eliminarli e continuare qui, oppure uscire dalla pagina.',
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(ctx, PlanCancelWithCommissionsAction.stay),
          style: AppActionStyles.dialogAction,
          child: const Text('Resta sulla pagina'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            ctx,
            PlanCancelWithCommissionsAction.deleteAndStay,
          ),
          child: const Text('Elimina incassi e resta'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(
            ctx,
            PlanCancelWithCommissionsAction.exitKeepCommissions,
          ),
          style: AppActionStyles.dialogAction,
          child: const Text('Esci (incassi restano)'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(
            ctx,
            PlanCancelWithCommissionsAction.exitDeleteCommissions,
          ),
          style: AppActionStyles.cancelText,
          child: const Text('Elimina incassi ed esci'),
        ),
      ],
    ),
  );
}

/// Rata con data e importo per export provvigioni.
class CommissionInstallmentPayment {
  final DateTime date;
  final double amount;

  const CommissionInstallmentPayment({
    required this.date,
    required this.amount,
  });
}

/// Voce da esportare verso provvigioni (un piano / una pratica).
class RepaymentPlanCommissionSlice {
  final String? planLabel;
  final double pdrAmount;
  final double cashAmount;

  const RepaymentPlanCommissionSlice({
    this.planLabel,
    required this.pdrAmount,
    this.cashAmount = 0,
  });
}

class RepaymentPlanCommissionExportRequest {
  final String creditorId;
  final String creditorName;
  final String planPaymentMethod;
  final String companyName;
  final DateTime collectionDate;
  final List<RepaymentPlanCommissionSlice> slices;

  const RepaymentPlanCommissionExportRequest({
    required this.creditorId,
    required this.creditorName,
    required this.planPaymentMethod,
    required this.companyName,
    required this.collectionDate,
    required this.slices,
  });
}

class RepaymentPlanCommissionExportResult {
  final int savedCount;
  final List<String> errors;
  final List<String> savedDocIds;

  const RepaymentPlanCommissionExportResult({
    required this.savedCount,
    required this.errors,
    this.savedDocIds = const [],
  });

  bool get hasErrors => errors.isNotEmpty;
}

abstract final class RepaymentPlanCommissionExporter {
  RepaymentPlanCommissionExporter._();

  static String? pdrCommissionKeyForPlanMethod(String metodo) {
    return switch (metodo) {
      'Bollettino' => 'pdrBollettiniPostali',
      'Cambiali' => 'pdrEffettiCambiari',
      _ => null,
    };
  }

  static CommissionPaymentOption? _optionForKey(
    List<CommissionPaymentOption> options,
    String key,
  ) {
    for (final option in options) {
      if (option.key == key) return option;
    }
    return null;
  }

  static double _commissionAmount(double amount, double rate) =>
      amount * rate / 100;

  static Future<RepaymentPlanCommissionExportResult> saveAll(
    RepaymentPlanCommissionExportRequest request,
  ) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return const RepaymentPlanCommissionExportResult(
        savedCount: 0,
        errors: ['Sessione scaduta. Effettua di nuovo l\'accesso.'],
      );
    }

    final creditorDoc = await FirebaseFirestore.instance
        .collection('creditors')
        .doc(request.creditorId)
        .get();
    if (!creditorDoc.exists) {
      return const RepaymentPlanCommissionExportResult(
        savedCount: 0,
        errors: ['Creditore non trovato.'],
      );
    }

    final creditorData = creditorDoc.data() ?? {};
    final options = CommissionPaymentResolver.entryOptions(creditorData);

    final pdrKey = pdrCommissionKeyForPlanMethod(request.planPaymentMethod);
    if (pdrKey == null) {
      return RepaymentPlanCommissionExportResult(
        savedCount: 0,
        errors: [
          'Metodo di pagamento piano non valido: ${request.planPaymentMethod}.',
        ],
      );
    }

    final pdrOption = _optionForKey(options, pdrKey);
    if (pdrOption == null) {
      return RepaymentPlanCommissionExportResult(
        savedCount: 0,
        errors: [
          'Nessuna aliquota provvigionale configurata per '
          '${CommissionPaymentResolver.labelForKey(pdrKey)}. '
          'Impostala da Imposta provvigioni.',
        ],
      );
    }

    final contantiOption = _optionForKey(options, 'contanti');

    final payloads = <Map<String, dynamic>>[];
    final errors = <String>[];

    for (final slice in request.slices) {
      final prefix = slice.planLabel == null ? '' : '${slice.planLabel}: ';

      if (slice.pdrAmount > 0.009) {
        final commission = _commissionAmount(slice.pdrAmount, pdrOption.rate);
        payloads.add(
          _entryPayload(
            userId: userId,
            collectionDate: request.collectionDate,
            companyName: request.companyName,
            amountCollected: slice.pdrAmount,
            creditorId: request.creditorId,
            creditorName: request.creditorName,
            payment: pdrOption,
            commissionAmount: commission,
          ),
        );
      }

      if (slice.cashAmount > 0.009) {
        if (contantiOption == null) {
          errors.add(
            '${prefix}acconto in contanti non registrato: aliquota '
            '«Contanti» non configurata per il creditore.',
          );
          continue;
        }
        final commission =
            _commissionAmount(slice.cashAmount, contantiOption.rate);
        payloads.add(
          _entryPayload(
            userId: userId,
            collectionDate: request.collectionDate,
            companyName: request.companyName,
            amountCollected: slice.cashAmount,
            creditorId: request.creditorId,
            creditorName: request.creditorName,
            payment: contantiOption,
            commissionAmount: commission,
          ),
        );
      }
    }

    if (payloads.isEmpty && errors.isEmpty) {
      return const RepaymentPlanCommissionExportResult(
        savedCount: 0,
        errors: ['Nessun importo da registrare negli incassi.'],
      );
    }

    return _commitCommissionPayloads(payloads, errors);
  }

  /// Elimina incassi registrati in sessione (es. annulla sviluppo piano).
  static Future<RepaymentPlanCommissionExportResult> deleteRegisteredCollections(
    List<String> docIds,
  ) async {
    final uniqueIds = docIds.toSet().where((id) => id.isNotEmpty).toList();
    if (uniqueIds.isEmpty) {
      return const RepaymentPlanCommissionExportResult(
        savedCount: 0,
        errors: [],
      );
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return const RepaymentPlanCommissionExportResult(
        savedCount: 0,
        errors: ['Sessione scaduta. Effettua di nuovo l\'accesso.'],
      );
    }

    final batch = FirebaseFirestore.instance.batch();
    final collection = FirebaseFirestore.instance.collection('calculations');
    var deleted = 0;

    for (final id in uniqueIds) {
      batch.delete(collection.doc(id));
      deleted++;
    }

    try {
      await batch.commit();
    } catch (_) {
      return const RepaymentPlanCommissionExportResult(
        savedCount: 0,
        errors: ['Errore durante l\'eliminazione degli incassi.'],
      );
    }

    return RepaymentPlanCommissionExportResult(
      savedCount: deleted,
      errors: const [],
      savedDocIds: uniqueIds,
    );
  }

  static Future<RepaymentPlanCommissionExportResult> _commitCommissionPayloads(
    List<Map<String, dynamic>> payloads,
    List<String> errors,
  ) async {
    if (payloads.isEmpty) {
      return RepaymentPlanCommissionExportResult(
        savedCount: 0,
        errors: errors,
      );
    }

    final batch = FirebaseFirestore.instance.batch();
    final collection = FirebaseFirestore.instance.collection('calculations');
    final now = FieldValue.serverTimestamp();
    final docIds = <String>[];

    for (final payload in payloads) {
      final ref = collection.doc();
      payload['createdAt'] = now;
      batch.set(ref, payload);
      docIds.add(ref.id);
    }

    try {
      await batch.commit();
    } catch (_) {
      return RepaymentPlanCommissionExportResult(
        savedCount: 0,
        errors: [
          ...errors,
          'Errore durante il salvataggio degli incassi.',
        ],
      );
    }

    return RepaymentPlanCommissionExportResult(
      savedCount: docIds.length,
      errors: errors,
      savedDocIds: docIds,
    );
  }

  /// Registra incassi da rate (saldo e stralcio o piani con calendario).
  static Future<RepaymentPlanCommissionExportResult> saveInstallmentCollections({
    required String creditorId,
    required String creditorName,
    required String companyName,
    required String paymentMethodKey,
    required CommissionExportDateMode dateMode,
    required DateTime singleCollectionDate,
    required List<CommissionInstallmentPayment> installments,
  }) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return const RepaymentPlanCommissionExportResult(
        savedCount: 0,
        errors: ['Sessione scaduta. Effettua di nuovo l\'accesso.'],
      );
    }

    if (installments.isEmpty) {
      return const RepaymentPlanCommissionExportResult(
        savedCount: 0,
        errors: ['Nessuna rata da registrare.'],
      );
    }

    final creditorDoc = await FirebaseFirestore.instance
        .collection('creditors')
        .doc(creditorId)
        .get();
    if (!creditorDoc.exists) {
      return const RepaymentPlanCommissionExportResult(
        savedCount: 0,
        errors: ['Creditore non trovato.'],
      );
    }

    final options =
        CommissionPaymentResolver.entryOptions(creditorDoc.data() ?? {});
    final payment = _optionForKey(options, paymentMethodKey);
    if (payment == null) {
      return RepaymentPlanCommissionExportResult(
        savedCount: 0,
        errors: [
          'Nessuna aliquota provvigionale configurata per '
          '${CommissionPaymentResolver.labelForKey(paymentMethodKey)}. '
          'Impostala da Imposta provvigioni.',
        ],
      );
    }

    final datedItems = dateMode == CommissionExportDateMode.singleDate
        ? [
            CommissionInstallmentPayment(
              date: singleCollectionDate,
              amount: installments.fold<double>(
                0,
                (total, item) => total + item.amount,
              ),
            ),
          ]
        : installments;

    final payloads = <Map<String, dynamic>>[];
    for (final item in datedItems) {
      if (item.amount <= 0.009) continue;
      final commission = _commissionAmount(item.amount, payment.rate);
      payloads.add(
        _entryPayload(
          userId: userId,
          collectionDate: item.date,
          companyName: companyName,
          amountCollected: item.amount,
          creditorId: creditorId,
          creditorName: creditorName,
          payment: payment,
          commissionAmount: commission,
        ),
      );
    }

    if (payloads.isEmpty) {
      return const RepaymentPlanCommissionExportResult(
        savedCount: 0,
        errors: ['Nessun importo da registrare negli incassi.'],
      );
    }

    return _commitCommissionPayloads(payloads, const []);
  }

  static Map<String, dynamic> _entryPayload({
    required String userId,
    required DateTime collectionDate,
    required String companyName,
    required double amountCollected,
    required String creditorId,
    required String creditorName,
    required CommissionPaymentOption payment,
    required double commissionAmount,
  }) {
    return {
      'userId': userId,
      'type': 'commission_entry',
      'collectionDate': Timestamp.fromDate(collectionDate),
      'companyName': companyName,
      'amountCollected': amountCollected,
      'creditorId': creditorId,
      'creditorName': creditorName,
      'paymentMethodKey': payment.key,
      'paymentMethodLabel': payment.label,
      'commissionRate': payment.rate,
      'commissionAmount': commissionAmount,
      'incentiveAmount': 0,
      'totalCommissionAmount': commissionAmount,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
