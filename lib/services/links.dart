import 'package:url_launcher/url_launcher.dart';

/// Outbound links: WhatsApp messages and the Google Sheet.
class Links {
  Links._();

  static Future<bool> open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// `wa.me` deep link — no WhatsApp Business API needed.
  static Future<bool> whatsapp(String number, String text) {
    final digits = _msisdn(number);
    if (digits.isEmpty) return Future.value(false);
    return open('https://wa.me/$digits?text=${Uri.encodeComponent(text)}');
  }

  /// Pakistani numbers reach WhatsApp as `92…` with no leading zero or plus.
  static String _msisdn(String raw) {
    var d = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.startsWith('0')) d = '92${d.substring(1)}';
    if (d.length == 10) d = '92$d';
    return d;
  }
}
