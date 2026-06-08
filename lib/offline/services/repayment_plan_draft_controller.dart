import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../repository/credit_calc_repository.dart';
import 'repayment_plan_draft_service.dart';

/// Autosave / restore bozze piani di rientro (solo modalità offline).
class RepaymentPlanDraftController {
  RepaymentPlanDraftController({
    required this.planType,
    required this.collectState,
    required this.applyState,
    this.debounce = const Duration(seconds: 2),
  });

  final String planType;
  final Map<String, dynamic> Function() collectState;
  final void Function(Map<String, dynamic> state) applyState;
  final Duration debounce;

  Timer? _timer;
  bool _restoring = false;

  bool get _enabled {
    try {
      return CreditCalcRepository.instance.isOfflineMode;
    } catch (_) {
      return false;
    }
  }

  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  Future<bool> restoreIfAny({BuildContext? snackbarContext}) async {
    if (!_enabled) return false;
    final userId = _userId;
    if (userId == null) return false;

    final state = await RepaymentPlanDraftService.loadDraft(
      userId: userId,
      planType: planType,
    );
    if (state == null || state.isEmpty) return false;

    _restoring = true;
    applyState(state);
    _restoring = false;

    if (snackbarContext != null && snackbarContext.mounted) {
      ScaffoldMessenger.of(snackbarContext).showSnackBar(
        const SnackBar(content: Text('Bozza del piano ripristinata.')),
      );
    }
    return true;
  }

  void scheduleSave() {
    if (_restoring || !_enabled) return;
    final userId = _userId;
    if (userId == null) return;

    _timer?.cancel();
    _timer = Timer(debounce, () {
      unawaited(
        RepaymentPlanDraftService.saveDraft(
          userId: userId,
          planType: planType,
          state: collectState(),
        ),
      );
    });
  }

  Future<void> clear() async {
    _timer?.cancel();
    if (!_enabled) return;
    final userId = _userId;
    if (userId == null) return;
    await RepaymentPlanDraftService.clearDraft(
      userId: userId,
      planType: planType,
    );
  }

  void dispose() {
    _timer?.cancel();
  }
}
