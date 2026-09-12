import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Photos, kept inside Firestore instead of Firebase Storage.
///
/// Storage would be the obvious home for them, but a new Firebase project
/// cannot switch it on without a card on file, and the farm does not want a
/// live card sitting on an account with no spending ceiling. So the pictures
/// are shrunk down and stored in the database next to the record they belong
/// to, which costs nothing and needs no second company.
///
/// The sums, for anyone who comes back to this later. A picture of a buffalo
/// at 800 points across is about 70 KB; the thumbnail the lists use is about
/// 6 KB. A hundred animals with five years of vet slips comes to a tenth of
/// the free gigabyte. If the farm ever outgrows that, moving to Storage is a
/// change to this one file.
class Photos {
  Photos._();

  /// Ask the camera for no more than this. The picker resizes on the phone
  /// before the file is ever read, so a 12 megapixel photo never has to be
  /// decoded whole.
  static const pickWidth = 800.0;
  static const pickQuality = 60;

  /// Thumbnails are for lists, where the picture is 60 points across.
  static const thumbWidth = 180;
  static const thumbQuality = 55;

  /// A Firestore document stops at a megabyte. Base64 adds a third on top of
  /// the bytes, so anything past this is refused and shrunk again.
  static const maxEncoded = 600 * 1024;

  /// Reads a picked photo and returns the two sizes, base64 encoded.
  ///
  /// The work happens off the main thread — a farmer taking a photo of a
  /// buffalo should not watch the screen freeze.
  static Future<FarmPhoto> prepare(File file) async {
    final bytes = await file.readAsBytes();
    return compute(shrinkPhoto, bytes);
  }

  /// `Image.memory` wants bytes; the record holds base64.
  static Uint8List? decode(String? data) {
    if (data == null || data.isEmpty) return null;
    try {
      return base64Decode(data);
    } catch (_) {
      return null;
    }
  }
}

/// One photo at the two sizes the app shows it in.
class FarmPhoto {
  const FarmPhoto({required this.thumb, required this.full});

  /// ~6 KB, lives on the record itself so lists need nothing else.
  final String thumb;

  /// ~70 KB, kept in its own document and read only when the picture is
  /// actually being looked at.
  final String full;
}

/// Shrinks a photo to the two sizes the app keeps. Top level because it runs
/// in a background isolate.
FarmPhoto shrinkPhoto(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('That file is not a picture.');
  }

  // The picker has already brought this down to about 800 across, so the
  // decode is cheap and this is only a tidy-up.
  var full = decoded.width > Photos.pickWidth
      ? img.copyResize(decoded, width: Photos.pickWidth.round())
      : decoded;

  var quality = Photos.pickQuality;
  var encoded = base64Encode(img.encodeJpg(full, quality: quality));

  // Belt and braces: a picture that still will not fit is shrunk until it
  // does, rather than failing the write in front of the user.
  while (encoded.length > Photos.maxEncoded && quality > 25) {
    quality -= 15;
    full = img.copyResize(full, width: (full.width * 0.8).round());
    encoded = base64Encode(img.encodeJpg(full, quality: quality));
  }

  final thumb = img.copyResize(full, width: Photos.thumbWidth);

  return FarmPhoto(
    thumb: base64Encode(img.encodeJpg(thumb, quality: Photos.thumbQuality)),
    full: encoded,
  );
}
