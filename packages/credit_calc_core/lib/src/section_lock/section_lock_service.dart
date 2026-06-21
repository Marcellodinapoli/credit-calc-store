import 'section_occupancy_result.dart';
import 'section_occupancy_service.dart';

abstract final class SectionLockService {
  static Future<SectionOccupancyResult> check(String sectionKey) {
    return SectionOccupancyService.check(sectionKey);
  }

  static Future<SectionOccupancyResult> tryAcquire(String sectionKey) {
    return SectionOccupancyService.tryAcquire(sectionKey);
  }

  static Stream<SectionOccupancyResult> watch(String sectionKey) {
    return SectionOccupancyService.watch(sectionKey);
  }

  static Future<void> claim(String sectionKey) async {
    await SectionOccupancyService.tryAcquire(sectionKey);
  }

  static Future<void> release(String sectionKey) {
    return SectionOccupancyService.release(sectionKey);
  }

  static Future<void> touch(String sectionKey) {
    return SectionOccupancyService.touch(sectionKey);
  }
}
