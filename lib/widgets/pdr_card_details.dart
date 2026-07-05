import 'package:flutter/material.dart';

import '../pages/creditcalc/commission_collections_shared.dart';
import '../services/installment_monitor_service.dart';

/// Righe dettaglio piano di rientro per card appuntamenti e promemoria.
class PdrCardDetailsLines extends StatelessWidget {
  const PdrCardDetailsLines({
    super.key,
    required this.detailsFuture,
  });

  final Future<InstallmentMonitorPdrDetails?> detailsFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<InstallmentMonitorPdrDetails?>(
      future: detailsFuture,
      builder: (context, snapshot) {
        final details = snapshot.data;
        if (details == null || !details.hasData) {
          return const SizedBox.shrink();
        }

        final style = TextStyle(
          color: Colors.grey.shade800,
          fontSize: 13,
          height: 1.35,
        );

        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rata da monitorare: ${details.rateIndex}/${details.totalRates}',
                style: style,
              ),
              if (details.pdrTotalAmount != null)
                Text(
                  'Importo totale PDR: '
                  '${CommissionCollectionsHelper.formatEuro(details.pdrTotalAmount!)}',
                  style: style,
                ),
              if (details.pdrDevelopedAt != null)
                Text(
                  'Sviluppo PDR: '
                  '${CommissionCollectionsHelper.formatDate(details.pdrDevelopedAt!)}',
                  style: style,
                ),
              if (details.installmentAmount != null)
                Text(
                  'Importo rata monitorata: '
                  '${CommissionCollectionsHelper.formatEuro(details.installmentAmount!)}',
                  style: style,
                ),
            ],
          ),
        );
      },
    );
  }
}
