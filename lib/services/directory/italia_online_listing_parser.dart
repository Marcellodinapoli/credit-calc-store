import '../../models/building_resident_entry.dart';
import 'directory_html_utils.dart';
import 'pagine_gialle_listing_parser.dart';

/// Parser condiviso per elenchi ItaliaOnline (Pagine Bianche e siti affini).
abstract final class ItaliaOnlineListingParser {
  static List<BuildingResidentEntry> parseListings({
    required String html,
    required String source,
    required String queryAddress,
  }) {
    final out = <BuildingResidentEntry>[];
    out.addAll(
      _parseListElementBlocks(
        html: html,
        source: source,
        queryAddress: queryAddress,
      ),
    );

    if (out.isEmpty && html.contains('search-itm card-listing')) {
      final pgEntries = PagineGialleListingParser.parseListings(html);
      for (final entry in pgEntries) {
        out.add(
          BuildingResidentEntry(
            displayName: entry.displayName,
            address: entry.address,
            source: source,
            phone: entry.phone,
            category: entry.category,
          ),
        );
      }
    }

    return out;
  }

  static List<BuildingResidentEntry> _parseListElementBlocks({
    required String html,
    required String source,
    required String queryAddress,
  }) {
    final sections = RegExp(
      r'<(?:section|div|article)\s+class="list-element[^"]*"[^>]*>(.*?)</(?:section|div|article)>',
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

      final category = DirectoryHtmlUtils.firstMatch(block, [
        RegExp(r'class="list-element__category[^"]*"[^>]*>([^<]+)'),
      ]);

      final phone = DirectoryHtmlUtils.firstMatch(block, [
        RegExp(r'class="[^"]*phone-numbers__number[^"]*"[^>]*>([^<]+)'),
        RegExp(r'href="tel:([^"]+)"'),
      ]) ??
          DirectoryHtmlUtils.extractPhone(block);

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
