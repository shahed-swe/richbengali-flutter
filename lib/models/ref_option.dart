/// A slug/label pair from GET /refs/:type
class RefOption {
  final String slug;
  final String label;

  const RefOption({required this.slug, required this.label});

  factory RefOption.fromJson(Map<String, dynamic> json) {
    return RefOption(
      slug: (json['slug'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
    );
  }
}

/// Utility: build a slug→label map from a list of RefOptions
Map<String, String> buildRefMap(List<RefOption> options) {
  return {for (final o in options) o.slug: o.label};
}

/// Format a slug nicely: look it up in map, or title-case it
String niceLabel(String? slug, [Map<String, String>? map]) {
  if (slug == null || slug.isEmpty) return '-';
  if (map != null && map.containsKey(slug)) return map[slug]!;
  return slug.replaceAll('_', ' ').split(' ').map((w) {
    if (w.isEmpty) return w;
    return w[0].toUpperCase() + w.substring(1);
  }).join(' ');
}
