import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

/// A newer build waiting on the Releases page.
class AppUpdate {
  const AppUpdate({required this.version, required this.apkUrl});

  final String version;
  final String apkUrl;
}

/// Tells the app when a newer APK has been published.
///
/// The farm installs by hand from GitHub Releases, so without this a fix can
/// sit there for weeks while everyone carries on with the old build. The check
/// is deliberately quiet: it never blocks anything, and any failure — no
/// signal, rate limit, a shape we did not expect — simply means no banner.
class UpdateCheck {
  UpdateCheck._();

  static const _releasesApi =
      'https://api.github.com/repos/saleemrehman2008/CharYarDairyFarm'
      '/releases/latest';

  /// Where to send someone whose build number could not be compared.
  static const releasesPage =
      'https://github.com/saleemrehman2008/CharYarDairyFarm/releases/latest';

  /// Fetched once per run of the app, then reused.
  static Future<AppUpdate?>? _cached;

  static Future<AppUpdate?> latest() => _cached ??= _fetch();

  static Future<AppUpdate?> _fetch() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = int.tryParse(info.buildNumber);
      if (current == null) return null;

      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);
      final request = await client.getUrl(Uri.parse(_releasesApi));
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/vnd.github+json',
      );
      final response = await request.close().timeout(
        const Duration(seconds: 12),
      );
      if (response.statusCode != 200) {
        client.close();
        return null;
      }

      final body = await response.transform(utf8.decoder).join();
      client.close();
      final release = jsonDecode(body) as Map<String, dynamic>;

      // Tags read "v1.0.0+12"; the build number is what actually increments.
      final tag = '${release['tag_name'] ?? ''}';
      final published = int.tryParse(tag.split('+').last);
      if (published == null || published <= current) return null;

      final assets = (release['assets'] as List?) ?? const [];
      for (final asset in assets.whereType<Map<String, dynamic>>()) {
        final name = '${asset['name'] ?? ''}';
        if (name.endsWith('.apk')) {
          return AppUpdate(
            version: tag,
            apkUrl: '${asset['browser_download_url'] ?? releasesPage}',
          );
        }
      }
      return AppUpdate(version: tag, apkUrl: releasesPage);
    } catch (_) {
      // An update check is never worth an error in front of the user.
      return null;
    }
  }
}
