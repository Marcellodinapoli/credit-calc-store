import '../../models/building_resident_entry.dart';
import '../../utils/building_residents_address_util.dart';
import 'italia_online_directory_service.dart';
import 'pagine_gialle_directory_service.dart';

/// Ricerca su Pagine Bianche (elenchi telefonici pubblici).
abstract final class PagineBiancheDirectoryService {
  static Future<List<BuildingResidentEntry>> searchByAddress(
    String address, {
    required String tab,
  }) async {
    final variants = _searchVariants(address);
    for (final query in variants) {
      final hits = await ItaliaOnlineDirectoryService.searchByAddress(
        query,
        host: 'www.paginebianche.it',
        source: 'paginebianche_$tab',
        tab: tab,
      );
      if (hits.isNotEmpty) return hits;
    }

    // Pagine Bianche spesso carica i risultati via JS: fallback su Pagine Gialle.
    for (final query in variants) {
      final pgHits = await PagineGialleDirectoryService.searchByAddress(query);
      if (pgHits.isNotEmpty) {
        return pgHits
            .map(
              (entry) => BuildingResidentEntry(
                displayName: entry.displayName,
                address: entry.address,
                source: 'paginebianche_$tab',
                phone: entry.phone,
                category: entry.category,
              ),
            )
            .toList();
      }
    }

    return [];
  }

  static List<String> _searchVariants(String address) {
    return BuildingResidentsAddressUtil.searchVariants(address);
  }
}
