/// URL del sito CreditPlanet in base al tipo utente Firestore (`users.type`).
abstract final class CreditPlanetSiteUrls {
  static const publicHost = 'creditplanet.netlify.app';
  static const workHost = 'creditplanet-work.netlify.app';

  static String hostForUserType(String? type) {
    final normalized = (type ?? 'public').toString().trim().toLowerCase();
    return normalized == 'work' ? workHost : publicHost;
  }

  static String siteUrlForUserType(String? type) =>
      'https://${hostForUserType(type)}';

  static String portalLabelForUserType(String? type) {
    final normalized = (type ?? 'public').toString().trim().toLowerCase();
    return normalized == 'work' ? 'Portale Work' : 'Sito pubblico';
  }
}

/// Alias per l'app store (menu account, link al sito web).
abstract final class CreditCoreSiteUrls {
  CreditCoreSiteUrls._();

  static const publicHost = CreditPlanetSiteUrls.publicHost;
  static const workHost = CreditPlanetSiteUrls.workHost;

  static String hostForUserType(String? type) =>
      CreditPlanetSiteUrls.hostForUserType(type);

  static String siteUrlForUserType(String? type) =>
      CreditPlanetSiteUrls.siteUrlForUserType(type);

  static String portalLabelForUserType(String? type) =>
      CreditPlanetSiteUrls.portalLabelForUserType(type);
}
