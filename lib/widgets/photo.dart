import 'dart:io';

import 'package:flutter/material.dart';

import '../services/photo_store.dart';
import '../theme/tokens.dart';

/// Any picture the farm has taken: a product, an animal, a vet's slip.
///
/// It takes both kinds. [data] is a picture kept in the record itself, which
/// is how they are stored now; [url] is one left over from Firebase Storage.
/// Whichever is there gets shown, so nothing that already works breaks.
class FarmPhotoView extends StatelessWidget {
  const FarmPhotoView({
    super.key,
    this.data,
    this.url = '',
    this.file,
    this.width,
    this.height,
    this.size,
    this.fit = BoxFit.cover,
  });

  /// Base64, straight off the record.
  final String? data;

  /// A Storage link, from before photos moved into the database.
  final String url;

  /// A picture just taken and not yet saved.
  final File? file;

  final double? width;
  final double? height;

  /// Shorthand for a square.
  final double? size;

  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final w = size ?? width;
    final h = size ?? height;
    final bytes = Photos.decode(data);

    Widget inner;
    if (file != null) {
      inner = Image.file(file!, fit: fit);
    } else if (bytes != null) {
      inner = Image.memory(bytes, fit: fit, gaplessPlayback: true);
    } else if (url.isNotEmpty) {
      inner = Image.network(
        url,
        fit: fit,
        errorBuilder: (_, _, _) => const _Mark(Icons.broken_image_outlined),
      );
    } else {
      inner = const _Mark(Icons.photo_camera_outlined);
    }

    return SizedBox(
      width: w,
      height: h,
      child: DecoratedBox(
        decoration: BoxDecoration(color: T.accent100, border: T.hair),
        child: inner,
      ),
    );
  }
}

/// A picture opened out to fill the screen.
///
/// Every photo in the app was a thumbnail and nothing more, which is half of
/// what a photo is for here: the register exists so an animal can be told
/// apart from the one standing next to her, and a hundred-pixel square of a
/// black buffalo tells nobody anything. Pinch to go closer — the marks that
/// identify an animal are small ones.
Future<void> showFarmPhoto(
  BuildContext context, {
  String? data,
  String url = '',
  String title = '',
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (page) => Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: T.cardTitle.copyWith(color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(page),
                  icon: const Icon(Icons.close, color: Colors.white),
                  tooltip: 'Close',
                ),
              ],
            ),
            Expanded(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: FarmPhotoView(
                    data: data,
                    url: url,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

class _Mark extends StatelessWidget {
  const _Mark(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) =>
      Center(child: Icon(icon, color: T.accent400));
}
