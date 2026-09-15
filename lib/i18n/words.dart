import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/session.dart';
import 'roman_urdu.dart';

/// The app in the reader's own language.
///
/// Screens are written in plain English and hand that English straight to
/// [L.t]; the Roman Urdu table in `roman_urdu.dart` is keyed by the same
/// English. Nothing here is a code — read the call site and you can see what
/// the screen says.
///
/// A phrase with no entry in the table falls back to the English, so an
/// untranslated corner reads a little English rather than reading
/// `settings.title.header`. That matters on a farm: a missing translation is a
/// nuisance, a missing string is a broken screen.
class L {
  const L(this.lang);

  final Lang lang;

  static const english = L(Lang.en);

  /// The reader's language, from their own account.
  ///
  /// Watches the session, so the whole app re-reads itself the moment the
  /// switch is flipped — no restart, no sign out.
  ///
  /// A widget drawn with no session above it — in a test, or a route pushed
  /// outside the app's shell — reads in English rather than throwing. A
  /// missing translation is a nuisance; a screen that will not draw because
  /// nobody is signed in is a fault.
  static L of(BuildContext context) {
    try {
      return L(context.watch<Session>().user?.lang ?? Lang.en);
    } on ProviderNotFoundException {
      return english;
    }
  }

  /// The same, without subscribing — for code outside the build method.
  static L read(BuildContext context) {
    try {
      return L(context.read<Session>().user?.lang ?? Lang.en);
    } on ProviderNotFoundException {
      return english;
    }
  }

  String t(String english) =>
      lang == Lang.en ? english : (romanUrdu[english] ?? english);

  /// A phrase with something dropped into it: `t2('%s ka bill', name)`.
  ///
  /// Kept separate from [t] so the table holds whole sentences rather than
  /// fragments a translator would have to guess the shape of.
  String t2(String english, Object a) => t(english).replaceFirst('%s', '$a');

  String t3(String english, Object a, Object b) =>
      t(english).replaceFirst('%s', '$a').replaceFirst('%s', '$b');
}
