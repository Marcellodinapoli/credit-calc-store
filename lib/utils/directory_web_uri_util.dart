import 'building_residents_address_util.dart';

/// URL per aprire ricerche elenco nel browser esterno.
abstract final class DirectoryWebUriUtil {
  static Uri italiaOnlineRicerca(
    String host,
    String address, {
    String tab = 'indirizzo',
  }) {
    return Uri.https(
      host,
      '/ricerca',
      BuildingResidentsAddressUtil.italiaOnlineQueryParams(
        address,
        tab: tab,
      ),
    );
  }

  /// Ricerca indirizzo su Pagine Gialle (`/ricerca/{via}/{città}`).
  ///
  /// Usa [pathSegments] senza pre-encoding: evita `%2520` e campi corrotti.
  static Uri pagineGialleRicerca(String address) {
    final trimmed = address.trim();
    final parts = BuildingResidentsAddressUtil.splitForDirectorySearch(trimmed);
    final street = parts.streetQuery.replaceAll(RegExp(r'\s+'), ' ').trim();
    final city = parts.cityQuery?.trim();

    if (street.isNotEmpty && city != null && city.isNotEmpty) {
      return Uri(
        scheme: 'https',
        host: 'www.paginegialle.it',
        pathSegments: ['ricerca', street, city],
      );
    }

    final fallback = street.isNotEmpty ? street : trimmed;
    return Uri(
      scheme: 'https',
      host: 'www.paginegialle.it',
      pathSegments: ['ricerca', fallback],
    );
  }
}
