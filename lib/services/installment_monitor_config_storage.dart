import '../services/installment_monitor_service.dart';

/// Persistenza configurazioni monitoraggio rata (locale di default).
abstract class InstallmentMonitorConfigStorage {
  static InstallmentMonitorConfigStorage instance =
      InMemoryInstallmentMonitorConfigStorage();

  Future<List<InstallmentMonitorConfig>> loadAll();

  Future<void> saveAll(List<InstallmentMonitorConfig> configs);
}

class InMemoryInstallmentMonitorConfigStorage
    implements InstallmentMonitorConfigStorage {
  List<InstallmentMonitorConfig> _cache = const [];

  @override
  Future<List<InstallmentMonitorConfig>> loadAll() async =>
      List<InstallmentMonitorConfig>.from(_cache);

  @override
  Future<void> saveAll(List<InstallmentMonitorConfig> configs) async {
    _cache = List<InstallmentMonitorConfig>.from(configs);
  }
}
