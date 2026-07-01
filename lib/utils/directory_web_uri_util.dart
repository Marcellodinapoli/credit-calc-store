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
}
