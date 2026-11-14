// Checks that every phrase the screens ask for has been translated — into
// Roman Urdu and into Urdu script, both.
//
//   dart run tool/check_words.dart
//
// The screens pass their own English to `L.t`, and both tables are keyed by
// that same English. A phrase with no entry falls back to English rather than
// breaking, which is the right behaviour at a gate at six in the morning —
// and exactly why nobody would notice it was missing. So it is checked here
// instead.
//
// Urdu script matters more than Roman Urdu here, not less: a man reading
// Roman Urdu can read the English fallback, badly but at all, because it is
// the same alphabet. A man reading Urdu script cannot read it at all, so a
// missing phrase is a hole in his page rather than a rough patch.

import 'dart:io';

/// `l.t('...')`, `l.t2('...', x)`, `l.t3('...', x, y)`, taking however many
/// adjacent string literals the phrase was wrapped across.
final _call = RegExp(r"""\bl\.t[234]?\(\s*((?:'(?:[^'\\]|\\.)*'\s*)+)""");
final _literal = RegExp(r"'(?:[^'\\]|\\.)*'");

/// A key in a table: one or more adjacent literals, then a colon.
final _key = RegExp(r"""((?:'(?:[^'\\]|\\.)*'\s*)+):""");

/// The two tables, by the file they live in and what to call them.
const _tables = {
  'lib/i18n/roman_urdu.dart': 'Roman Urdu',
  'lib/i18n/urdu.dart': 'Urdu',
};

void main() {
  final asked = <String, String>{}; // phrase -> where it was first seen

  for (final file in Directory('lib').listSync(recursive: true)) {
    if (file is! File || !file.path.endsWith('.dart')) continue;
    final path = file.path.replaceAll(r'\', '/');
    if (_tables.keys.any(path.endsWith)) continue;

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

  stdout.writeln('${asked.length} phrases asked for');

  var short = false;
  for (final table in _tables.entries) {
    final missing = _missingFrom(table.key, asked.keys);
    if (missing.isEmpty) {
      stdout.writeln('All of them have ${table.value}.');
      continue;
    }
    short = true;
    stdout.writeln('\n${missing.length} with no ${table.value}:\n');
    for (final phrase in missing) {
      stdout.writeln("  '$phrase':  (${asked[phrase]})");
    }
  }
  if (short) exitCode = 1;
}

/// Which of [asked] the table in [path] has no line for.
///
/// The table's keys are read the same way its call sites are: a long phrase
/// is wrapped across several lines in both places, and Dart joins the pieces.
/// Comparing the raw source instead would report a translation as missing
/// purely because the line happened to wrap.
List<String> _missingFrom(String path, Iterable<String> asked) {
  final table = File(path).readAsStringSync();
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
  return asked.where((p) => !translated.contains(p)).toList()..sort();
}
