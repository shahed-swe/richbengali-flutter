import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Matches links people actually paste: anything with a scheme, anything
/// starting `www.`, and bare hosts on a common TLD (with an optional path).
/// Deliberately conservative about bare hosts so ordinary prose like
/// "wait.ok" is not turned into a link.
final RegExp _urlRegex = RegExp(
  r'(?:https?://|www\.)[^\s<>"]+'
  r'|(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+'
  r'(?:com|net|org|io|co|dev|app|ai|me|info|biz|tv|xyz|online|site|shop|store|news|tech|live|cloud|edu|gov|uk|bd|in)'
  r'(?:/[^\s<>"]*)?',
  caseSensitive: false,
);

/// Trailing punctuation almost always belongs to the sentence, not the link —
/// "see https://x.com." should open `https://x.com`.
const String _trailingPunctuation = '.,;:!?"\'）)]}>';

String _trimTrailing(String url) {
  var out = url;
  while (out.isNotEmpty && _trailingPunctuation.contains(out[out.length - 1])) {
    // Keep a closing bracket that has a matching opener inside the url itself.
    final last = out[out.length - 1];
    if (last == ')' && out.contains('(')) break;
    out = out.substring(0, out.length - 1);
  }
  return out;
}

Uri? _toUri(String raw) {
  final withScheme =
      RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(raw) ? raw : 'https://$raw';
  final uri = Uri.tryParse(withScheme);
  if (uri == null || uri.host.isEmpty) return null;
  return uri;
}

Future<void> _open(BuildContext context, String raw) async {
  final uri = _toUri(raw);
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (uri == null) {
    messenger?.showSnackBar(
      const SnackBar(content: Text("That link doesn't look valid.")),
    );
    return;
  }
  try {
    // externalApplication so the link leaves the app for the real browser,
    // rather than opening a sheet inside the chat.
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Could not open $uri')),
      );
    }
  } catch (_) {
    messenger?.showSnackBar(
      SnackBar(content: Text('Could not open $uri')),
    );
  }
}

/// Message text with any URLs in it rendered as tappable links.
class LinkifiedText extends StatefulWidget {
  const LinkifiedText({
    super.key,
    required this.text,
    required this.style,
    required this.linkStyle,
  });

  final String text;
  final TextStyle style;
  final TextStyle linkStyle;

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  /// Held so they can be disposed — a TapGestureRecognizer created in build
  /// and dropped on the floor leaks.
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();

    final text = widget.text;
    final matches = _urlRegex.allMatches(text).toList();
    if (matches.isEmpty) {
      return Text(text, style: widget.style);
    }

    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final m in matches) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, m.start)));
      }

      final raw = text.substring(m.start, m.end);
      final link = _trimTrailing(raw);
      final remainder = raw.substring(link.length);

      final recognizer = TapGestureRecognizer()
        ..onTap = () => _open(context, link);
      _recognizers.add(recognizer);

      spans.add(TextSpan(
        text: link,
        style: widget.linkStyle,
        recognizer: recognizer,
      ));
      if (remainder.isNotEmpty) spans.add(TextSpan(text: remainder));

      cursor = m.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return Text.rich(TextSpan(style: widget.style, children: spans));
  }
}
