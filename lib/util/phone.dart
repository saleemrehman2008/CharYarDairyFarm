/// Pakistani mobile numbers, checked and tidied before they are stored.
///
/// A number is how the farm reaches a customer when the milk is at the gate, so
/// a typo is not harmless — a wrong digit means a knock at the wrong door and a
/// delivery that never lands. Everything is kept in one shape, `03XXXXXXXXX`,
/// whichever way it was typed.
abstract final class Phone {
  /// Digits only, with a leading country code turned back into the local `0`.
  static String normalise(String raw) {
    var d = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.startsWith('0092')) d = d.substring(4);
    if (d.startsWith('92') && d.length == 12) d = d.substring(2);
    // 3001234567 — typed without the leading zero.
    if (d.length == 10 && d.startsWith('3')) d = '0$d';
    return d;
  }

  /// Pakistani mobiles are eleven digits and begin 03.
  static bool isValid(String raw) {
    final d = normalise(raw);
    return d.length == 11 && d.startsWith('03');
  }

  /// `0300 1234567`, which is how people read a number back to each other.
  static String pretty(String raw) {
    final d = normalise(raw);
    if (d.length != 11) return raw.trim();
    return '${d.substring(0, 4)} ${d.substring(4)}';
  }

  /// What to tell someone who typed it wrong.
  static const hint = '03xx xxxxxxx';
  static const error = 'A mobile number is 11 digits and starts with 03.';
}
