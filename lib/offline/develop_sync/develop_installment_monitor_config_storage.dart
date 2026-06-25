import '../../services/installment_monitor_config_storage.dart';
import '../../services/installment_monitor_service.dart';
import 'develop_installment_monitor_repository.dart';

class DevelopInstallmentMonitorConfigStorage
    implements InstallmentMonitorConfigStorage {
  DevelopInstallmentMonitorConfigStorage(this._repository);

  final DevelopInstallmentMonitorRepository _repository;

  @override
  Future<List<InstallmentMonitorConfig>> loadAll() => _repository.loadAll();

  @override
  Future<void> saveAll(List<InstallmentMonitorConfig> configs) =>
      _repository.saveAll(configs);
}
