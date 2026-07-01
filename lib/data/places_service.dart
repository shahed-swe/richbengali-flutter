import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class PlaceSuggestion {
  final String displayName;
  final String city;
  final String? country;

  const PlaceSuggestion({
    required this.displayName,
    required this.city,
    this.country,
  });
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Looks up city suggestions via the OpenStreetMap Nominatim search API.
///
/// Uses a dedicated, unauthenticated [Dio] instance — this must NOT reuse the
/// app's authed `dioProvider`/base URL, since Nominatim is a separate public
/// service that requires its own User-Agent header.
class PlacesService {
  PlacesService() : _dio = Dio();

  final Dio _dio;

  static const _baseUrl = 'https://nominatim.openstreetmap.org/search';

  Future<List<PlaceSuggestion>> searchCities(String query, {CancelToken? cancelToken}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    try {
      final resp = await _dio.get(
        _baseUrl,
        queryParameters: {
          'q': trimmed,
          'format': 'json',
          'addressdetails': '1',
          'limit': '6',
        },
        options: Options(
          headers: {'User-Agent': 'RichBengali/1.0 (com.richbengali.app)'},
        ),
        cancelToken: cancelToken,
      );

      final data = resp.data;
      if (data is! List) return [];

      final seen = <String>{};
      final results = <PlaceSuggestion>[];

      for (final item in data) {
        if (item is! Map) continue;
        final displayName = (item['display_name'] ?? '').toString();
        final address = item['address'] is Map ? item['address'] as Map : const {};

        String? city = _stringOrNull(address['city']) ??
            _stringOrNull(address['town']) ??
            _stringOrNull(address['village']) ??
            _stringOrNull(address['state']) ??
            _stringOrNull(item['name']) ??
            (displayName.isNotEmpty ? displayName.split(',').first.trim() : null);

        if (city == null || city.isEmpty) continue;
        if (!seen.add(city)) continue;

        results.add(PlaceSuggestion(
          displayName: displayName.isNotEmpty ? displayName : city,
          city: city,
          country: _stringOrNull(address['country']),
        ));
      }

      return results;
    } catch (_) {
      // Tolerate all errors (network, cancellation, parsing) — degrade to no suggestions.
      return [];
    }
  }

  String? _stringOrNull(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final placesServiceProvider = Provider<PlacesService>((ref) => PlacesService());
