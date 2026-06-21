import '../subscription/public_usage_service.dart';
import 'section_lock_config.dart';

abstract final class SectionLockService {
  static Future<PublicUsageCheckResult> check(String sectionKey) {
    final metric = SectionLockConfig.metricFor(sectionKey);
    if (metric == null) {
      return Future.value(PublicUsageCheckResult.skipped);
    }
    return PublicUsageService.check(metric);
  }
}
