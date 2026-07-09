import 'package:flutter/foundation.dart';

class AccountMenuBadges {
  final bool directSupport;
  final bool community;
  final bool courses;
  final bool warmup;
  final bool roleplay;
  final bool jobOffers;

  const AccountMenuBadges({
    this.directSupport = false,
    this.community = false,
    this.courses = false,
    this.warmup = false,
    this.roleplay = false,
    this.jobOffers = false,
  });

  bool get hasAny =>
      directSupport ||
      community ||
      courses ||
      warmup ||
      roleplay ||
      jobOffers;

  bool get hasCreditForm => courses || warmup || roleplay;

  bool get hasCreditJob => jobOffers;

  bool get hasArea => directSupport || community;
}

/// Badge sul menù tre puntini e sulle voci correlate.
final class AccountMenuBadgeNotifier {
  AccountMenuBadgeNotifier._();

  static final AccountMenuBadgeNotifier instance = AccountMenuBadgeNotifier._();

  final ValueNotifier<AccountMenuBadges> badges =
      ValueNotifier(const AccountMenuBadges());
}
