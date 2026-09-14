// Checks that every phrase the screens ask for has Roman Urdu.
//
//   dart run tool/check_words.dart
//
// The screens pass their own English to `L.t`, and the table in
// `lib/i18n/roman_urdu.dart` is keyed by that same English. A phrase with no
// entry falls back to English rather than breaking, which is the right
// behaviour at a gate at six in the morning — and exactly why nobody would
// notice it was missing. So it is checked here instead.

import 'dart:io';

/// `l.t('...')`, `l.t2('...', x)`, `l.t3('...', x, y)`, taking however many
/// adjacent string literals the phrase was wrapped across.
final _call = RegExp(r"""\bl\.t[23]?\(\s*((?:'(?:[^'\\]|\\.)*'\s*)+)""");
final _literal = RegExp(r"'(?:[^'\\]|\\.)*'");

/// A key in the table: one or more adjacent literals, then a colon.
final _key = RegExp(r"""((?:'(?:[^'\\]|\\.)*'\s*)+):""");

void main() {
  final asked = <String, String>{}; // phrase -> where it was first seen

  for (final file in Directory('lib').listSync(recursive: true)) {
    if (file is! File || !file.path.endsWith('.dart')) continue;
    if (file.path.contains('roman_urdu')) continue;

    final source = file.readAsStringSync();
    for (final match in _call.allMatches(source)) {
      final phrase = _literal
          .allMatches(match.group(1)!)
          .map((m) => m.group(0)!)
          .map((s) => s.substring(1, s.length - 1))
          .join();
      if (phrase.trim().isEmpty) continue;
      asked.putIfAbsent(phrase, () => file.path);
    }
  }

  // The table's keys are read the same way its call sites are: a long phrase
  // is wrapped across several lines in both places, and Dart joins the pieces.
  // Comparing the raw source instead would report a translation as missing
  // purely because the line happened to wrap.
  final table = File('lib/i18n/roman_urdu.dart').readAsStringSync();
  final translated = <String>{};
  for (final entry in _key.allMatches(table)) {
    translated.add(
      _literal
          .allMatches(entry.group(1)!)
          .map((m) => m.group(0)!)
          .map((s) => s.substring(1, s.length - 1))
          .join(),
    );
  }

  final missing = asked.keys.where((p) => !translated.contains(p)).toList()
    ..sort();

  stdout.writeln('${asked.length} phrases asked for');
  if (missing.isEmpty) {
    stdout.writeln('All of them have Roman Urdu.');
    return;
  }

  stdout.writeln('${missing.length} with no Roman Urdu:\n');
  for (final phrase in missing) {
    stdout.writeln("  '$phrase':  (${asked[phrase]})");
  }
  exitCode = 1;
}
