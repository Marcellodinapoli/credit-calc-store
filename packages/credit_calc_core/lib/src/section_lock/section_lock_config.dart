abstract final class SectionLockConfig {
  static String? titleFor(String sectionKey) => switch (sectionKey) {
        'repayment_plan' => 'Piano di rientro',
        'balance_write_off' => 'Estinzione saldo',
        _ => null,
      };

  static bool isSupported(String sectionKey) => titleFor(sectionKey) != null;
}
