import '../../models/building_resident_entry.dart';
import '../../utils/building_residents_address_util.dart';
import 'directory_html_utils.dart';

/// Parser condiviso per elenchi ItaliaOnline (Pagine Bianche e siti affini).
abstract final class ItaliaOnlineListingParser {
  static List<BuildingResidentEntry> parseListings({
    required String html,
    required String source,
    required String queryAddress,
  }) {
    final sections = RegExp(
      r'<section class="list-element[^"]*"[^>]*>(.*?)</section>',
      dotAll: true,
    ).allMatches(html);

    final out = <BuildingResidentEntry>[];
    for (final section in sections) {
      final block = section.group(1) ?? '';
      if (block.isEmpty) continue;

      final name = DirectoryHtmlUtils.firstMatch(block, [
        RegExp(
          r'class="list-element__title[^"]*"[^>]*>.*?<a[^>]*>([^<]+)',
          dotAll: true,
        ),
        RegExp(
          r'class="list-element__title[^"]*"[^>]*>.*?>([^<]+)',
          dotAll: true,
        ),
        RegExp(r'class="[^"]*fn[^"]*"[^>]*>([^<]+)'),
      ]);
      if (name == null || name.isEmpty) continue;

      final address = DirectoryHtmlUtils.firstMatch(block, [
        RegExp(r'class="[^"]*street-address[^"]*"[^>]*>([^<]+)'),
        RegExp(
          r'class="[^"]*list-element__address[^"]*"[^>]*>.*?street-address[^>]*>([^<]+)',
          dotAll: true,
        ),
        RegExp(
          r'class="[^"]*adr[^"]*"[^>]*>.*?<span[^>]*>([^<]+)',
          dotAll: true,
        ),
      ]);

      final cleanAddress = DirectoryHtmlUtils.decodeHtmlEntities(address ?? '')
          .replaceAll(RegExp(r'\s*-\s*$'), '')
          .trim();
      if (cleanAddress.isEmpty) continue;
      if (!BuildingResidentsAddressUtil.matchesListingAddress(
        queryAddress,
        cleanAddress,
        extraText: category != null
            ? DirectoryHtmlUtils.decodeHtmlEntities(category)
            : null,
      )) {
        continue;
      }

      final phone = DirectoryHtmlUtils.firstMatch(block, [
        RegExp(r'class="[^"]*phone-numbers__number[^"]*"[^>]*>([^<]+)'),
        RegExp(r'href="tel:([^"]+)"'),
      ]) ??
          DirectoryHtmlUtils.extractPhone(block);

      final category = DirectoryHtmlUtils.firstMatch(block, [
        RegExp(r'class="list-element__category[^"]*"[^>]*>([^<]+)'),
      ]);

      final cleanName = DirectoryHtmlUtils.decodeHtmlEntities(name)
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      out.add(
        BuildingResidentEntry(
          displayName: cleanName,
          address: cleanAddress,
          source: source,
          phone: phone?.replaceAll(RegExp(r'\s+'), ''),
          category: category != null
              ? DirectoryHtmlUtils.decodeHtmlEntities(category)
              : null,
        ),
      );
    }
    return out;
  }
}
