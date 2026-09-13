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

  final table = File('lib/i18n/roman_urdu.dart').readAsStringSync();

  // Compared as source, not as runtime strings: both sides are written the
  // same way in Dart, escapes and all, so this needs no unescaping to be right.
  final missing = asked.keys.where((p) => !table.contains("'$p':")).toList()
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
