import '../../models/building_resident_entry.dart';
import 'italia_online_directory_service.dart';

/// Ricerca su Pagine Bianche (elenchi telefonici pubblici).
abstract final class PagineBiancheDirectoryService {
  static Future<List<BuildingResidentEntry>> searchByAddress(
    String address, {
    required String tab,
  }) {
    return ItaliaOnlineDirectoryService.searchByAddress(
      address,
      host: 'www.paginebianche.it',
      source: 'paginebianche_$tab',
      tab: tab,
    );
  }
}
