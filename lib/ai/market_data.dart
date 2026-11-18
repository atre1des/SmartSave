import 'dart:convert';
import 'dart:io';

/// A single retrieved financial-data record.
///
/// Every record identifies its source, when it was retrieved, the data
/// timestamp where available, and whether the information is live, delayed,
/// historical, or unavailable. This makes the provenance of every number
/// explicit so the assistant can never silently present stale or invented
/// data as current.
class MarketDataRecord {
  const MarketDataRecord({
    required this.source,
    required this.retrievedAt,
    required this.dataTimestamp,
    required this.freshness,
    required this.payload,
    this.error,
  });

  /// Human-readable source name, e.g. "National Bank of Kazakhstan".
  final String source;

  /// When the record was fetched (UTC).
  final DateTime retrievedAt;

  /// The timestamp the data itself refers to, when the source provides one.
  final DateTime? dataTimestamp;

  /// Whether the data is live, delayed, historical, or unavailable.
  final MarketDataFreshness freshness;

  /// The retrieved data as a JSON-encodable map.
  final Map<String, dynamic> payload;

  /// Error message if retrieval failed (freshness is [unavailable]).
  final String? error;

  bool get isAvailable => freshness != MarketDataFreshness.unavailable;

  Map<String, dynamic> toJson() => {
        'source': source,
        'retrievedAt': retrievedAt.toIso8601String(),
        'dataTimestamp': dataTimestamp?.toIso8601String(),
        'freshness': freshness.name,
        'payload': payload,
        if (error != null) 'error': error,
      };
}

enum MarketDataFreshness { live, delayed, historical, unavailable }

/// Result of a market-data lookup.
class MarketDataResult {
  const MarketDataResult({required this.records, this.error});

  final List<MarketDataRecord> records;
  final String? error;

  bool get hasData => records.isNotEmpty;
}

/// Modular retrieval layer for Kazakhstan financial data.
///
/// Only free, legitimate sources are implemented. Each source is isolated in
/// its own method so a failing source never breaks the others. If a source
/// cannot be reached, the result reports it as [MarketDataFreshness.unavailable]
/// rather than fabricating data.
///
/// Verified free sources:
/// - National Bank of Kazakhstan official exchange rates (RSS/XML, no auth).
///
/// Not integrated (no verified free API found):
/// - KASE (kase.kz): HTML pages only, no public JSON API found.
/// - AIX (aix.kz): redirects to aixkz.com, no public JSON API found.
class KazakhstanMarketData {
  KazakhstanMarketData({HttpClient? httpClient})
      : _http = httpClient ?? HttpClient();

  final HttpClient _http;

  static const _nbkRatesUrl = 'https://nationalbank.kz/rss/rates_all.xml';

  /// Fetches official NBK exchange rates.
  ///
  /// Source: https://nationalbank.kz/rss/rates_all.xml
  /// Verified free, no authentication required. Data is the official rate
  /// sheet published by the National Bank (delayed relative to intraday).
  Future<MarketDataResult> fetchNbkExchangeRates() async {
    final retrievedAt = DateTime.now().toUtc();
    try {
      final request = await _http.getUrl(Uri.parse(_nbkRatesUrl));
      final response = await request.close();
      if (response.statusCode != 200) {
        return MarketDataResult(
          records: [
            _unavailableRecord(
              retrievedAt,
              'NBK returned HTTP ${response.statusCode}',
            ),
          ],
          error: 'HTTP ${response.statusCode}',
        );
      }
      final body = await response.transform(utf8.decoder).join();
      final rates = _parseNbkRatesXml(body);
      return MarketDataResult(
        records: [
          MarketDataRecord(
            source: 'National Bank of Kazakhstan (official rates RSS)',
            retrievedAt: retrievedAt,
            dataTimestamp: _extractDateFromXml(body),
            freshness: MarketDataFreshness.delayed,
            payload: {'rates': rates},
          ),
        ],
      );
    } catch (e) {
      return MarketDataResult(
        records: [_unavailableRecord(retrievedAt, 'NBK rates fetch failed: $e')],
        error: e.toString(),
      );
    }
  }

  MarketDataRecord _unavailableRecord(DateTime retrievedAt, String error) =>
      MarketDataRecord(
        source: 'National Bank of Kazakhstan (official rates RSS)',
        retrievedAt: retrievedAt,
        dataTimestamp: null,
        freshness: MarketDataFreshness.unavailable,
        payload: const {},
        error: error,
      );

  /// Parses the NBK RSS/XML into a list of maps.
  ///
  /// The feed layout can change; we keep the raw title/description text so
  /// the assistant sees exactly what the source published rather than a
  /// mis-parsed number.
  static List<Map<String, dynamic>> _parseNbkRatesXml(String xml) {
    final rates = <Map<String, dynamic>>[];
    final itemMatches = RegExp(r'<item>(.*?)</item>', dotAll: true).allMatches(xml);
    for (final m in itemMatches) {
      final item = m.group(1) ?? '';
      final title = RegExp(r'<title>(.*?)</title>', dotAll: true).firstMatch(item)?.group(1);
      final description = RegExp(r'<description>(.*?)</description>', dotAll: true).firstMatch(item)?.group(1);
      if (title != null) {
        rates.add({
          'title': _decodeXmlEntities(title),
          if (description != null) 'description': _decodeXmlEntities(description),
        });
      }
    }
    return rates;
  }

  static DateTime? _extractDateFromXml(String xml) {
    final pubDate = RegExp(r'<pubDate>(.*?)</pubDate>', dotAll: true).firstMatch(xml)?.group(1);
    if (pubDate != null) {
      final d = DateTime.tryParse(pubDate.trim());
      if (d != null) return d;
    }
    return null;
  }

  static String _decodeXmlEntities(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'");
}

/// Formats a market-data result as a provenance block for the system prompt.
String formatMarketDataForPrompt(MarketDataResult result) {
  if (!result.hasData) {
    return 'No current Kazakhstan market data could be retrieved.';
  }
  final buffer = StringBuffer();
  for (final r in result.records) {
    buffer.writeln('[Source] ${r.source}');
    buffer.writeln('[Retrieved at] ${r.retrievedAt.toIso8601String()}');
    buffer.writeln(
      '[Data timestamp] ${r.dataTimestamp?.toIso8601String() ?? "not provided by source"}',
    );
    buffer.writeln('[Freshness] ${r.freshness.name}');
    if (r.error != null) {
      buffer.writeln('[Status] unavailable: ${r.error}');
    } else {
      buffer.writeln('[Status] retrieved successfully');
      buffer.writeln('[Data]');
      buffer.writeln(jsonEncode(r.payload));
    }
    buffer.writeln();
  }
  return buffer.toString().trimRight();
}
