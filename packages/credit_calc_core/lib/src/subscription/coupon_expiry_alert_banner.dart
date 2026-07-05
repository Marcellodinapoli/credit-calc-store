import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'coupon_expiry_alert_service.dart';
import 'user_subscription_service.dart';

/// Banner scadenza coupon (3 giorni prima e ultimo giorno attivo).
class CouponExpiryAlertBanner extends StatefulWidget {
  const CouponExpiryAlertBanner({super.key});

  @override
  State<CouponExpiryAlertBanner> createState() =>
      _CouponExpiryAlertBannerState();
}

class _CouponExpiryAlertBannerState extends State<CouponExpiryAlertBanner> {
  var _lastDayDismissed = false;
  DateTime? _lastDayDismissedFor;
  var _resolveGeneration = 0;

  Future<void> _dismiss(CouponExpiryAlert alert) async {
    if (alert.phase == CouponExpiryAlertPhase.advance) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await CouponExpiryAlertService.markAdvanceWarningSeen(
          uid,
          alert.expiresAt,
        );
      }
      if (!mounted) return;
      setState(() => _resolveGeneration++);
      return;
    }

    setState(() {
      _lastDayDismissed = true;
      _lastDayDismissedFor = alert.expiresAt;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: UserSubscriptionService.watchCurrent(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        return FutureBuilder<CouponExpiryAlert?>(
          key: ValueKey(
            '${snapshot.data!.limitsEffectExpiresAt?.millisecondsSinceEpoch}'
            '_$_resolveGeneration',
          ),
          future: CouponExpiryAlertService.resolveForSnapshot(snapshot.data!),
          builder: (context, alertSnap) {
            final alert = alertSnap.data;
            if (alert == null) return const SizedBox.shrink();

            if (alert.phase == CouponExpiryAlertPhase.lastDay &&
                _lastDayDismissed &&
                _lastDayDismissedFor == alert.expiresAt) {
              return const SizedBox.shrink();
            }

            final isLastDay = alert.phase == CouponExpiryAlertPhase.lastDay;
            return Material(
              color: isLastDay ? const Color(0xFFFFF7ED) : const Color(0xFFEFF6FF),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isLastDay
                            ? Icons.event_busy_outlined
                            : Icons.info_outline,
                        size: 20,
                        color: isLastDay
                            ? Colors.orange.shade900
                            : Colors.blue.shade800,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          alert.message,
                          style: TextStyle(
                            color: isLastDay
                                ? Colors.orange.shade900
                                : Colors.blue.shade900,
                            height: 1.4,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Chiudi avviso',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _dismiss(alert),
                        icon: const Icon(Icons.close, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
