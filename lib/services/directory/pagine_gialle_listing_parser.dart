import '../../models/building_resident_entry.dart';
import 'directory_html_utils.dart';

/// Parser risultati Pagine Gialle (layout search-itm).
abstract final class PagineGialleListingParser {
  static List<BuildingResidentEntry> parseListings(String html) {
    final items = RegExp(
      r'class="search-itm card-listing card-listing--element[^"]*"[^>]*>(.*?)(?=class="search-itm card-listing card-listing--element|$)',
      dotAll: true,
    ).allMatches(html);

    final out = <BuildingResidentEntry>[];
    for (final item in items) {
      final block = item.group(1) ?? '';
      if (block.isEmpty) continue;

      final nameHtml = DirectoryHtmlUtils.firstMatch(block, [
        RegExp(
          r'class="search-itm__rag[^"]*"[^>]*>(.*?)</h2>',
          dotAll: true,
        ),
      ]);
      if (nameHtml == null || nameHtml.isEmpty) continue;

      final name = DirectoryHtmlUtils.decodeHtmlEntities(
        nameHtml.replaceAll(RegExp(r'<[^>]+>'), ' '),
      ).replaceAll(RegExp(r'\s+'), ' ').trim();
      if (name.isEmpty) continue;

      final address = DirectoryHtmlUtils.firstMatch(block, [
        RegExp(
          r'class="search-itm__adr"[^>]*>.*?<div[^>]*>\s*([^<]+)',
          dotAll: true,
        ),
      ]);
      final cleanAddress = DirectoryHtmlUtils.decodeHtmlEntities(address ?? '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      final description = DirectoryHtmlUtils.firstMatch(block, [
        RegExp(r'class="search-itm__dsc"[^>]*>\s*([^<]+)', dotAll: true),
      ]);
      final cleanDescription = DirectoryHtmlUtils.decodeHtmlEntities(
        description ?? '',
      ).replaceAll(RegExp(r'\s+'), ' ').trim();

      final category = DirectoryHtmlUtils.firstMatch(block, [
        RegExp(r'class="search-itm__category"[^>]*>\s*([^<]+)', dotAll: true),
      ]);

      final phone = DirectoryHtmlUtils.firstMatch(block, [
        RegExp(r'class="search-itm__phone-item[^"]*"[^>]*>([^<]+)'),
        RegExp(r'href="tel:([^"]+)"'),
      ]) ??
          DirectoryHtmlUtils.extractPhone(block);

      final listingAddress = cleanAddress.isNotEmpty
          ? cleanAddress
          : _extractAddressFromText(cleanDescription);
      if (listingAddress == null || listingAddress.isEmpty) continue;

      final details = [
        if (category != null)
          DirectoryHtmlUtils.decodeHtmlEntities(category).trim(),
        if (cleanDescription.isNotEmpty) cleanDescription,
      ].where((part) => part.isNotEmpty).join(' · ');

      out.add(
        BuildingResidentEntry(
          displayName: name,
          address: listingAddress,
          source: 'paginegialle',
          phone: phone?.replaceAll(RegExp(r'\s+'), ''),
          category: details.isEmpty ? null : details,
        ),
      );
    }
    return out;
  }

  static String? _extractAddressFromText(String text) {
    final withCivic = RegExp(
      r'((?:Via|Viale|Piazza|Corso|Largo|Vicolo|Strada|Frazione|Località)[^.,\n]{3,80}\d+[a-zA-Z]?)',
      caseSensitive: false,
    ).firstMatch(text);
    if (withCivic != null) return withCivic.group(1)!.trim();

    final withoutCivic = RegExp(
      r'((?:Via|Viale|Piazza|Corso|Largo|Vicolo|Strada|Frazione|Località)[^.,\n]{3,60})',
      caseSensitive: false,
    ).firstMatch(text);
    return withoutCivic?.group(1)?.trim();
  }
}
