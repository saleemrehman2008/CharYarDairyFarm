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

class _Mark extends StatelessWidget {
  const _Mark(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) =>
      Center(child: Icon(icon, color: T.accent400));
}
