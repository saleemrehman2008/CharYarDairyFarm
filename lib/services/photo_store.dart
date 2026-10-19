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
  /// Ask the picker for enough to read small print on a slip. The camera
  /// resizes on the phone before the file is ever read, so this costs
  /// nothing on a buffalo — she is brought down again in [shrinkFor].
  static const pickWidth = 1600.0;
  static const pickQuality = 60;

  /// Thumbnails are for lists, where the picture is 60 points across.
  static const thumbWidth = 180;
  static const thumbQuality = 55;

  /// A Firestore document stops at a megabyte. Base64 adds a third on top of
  /// the bytes, so anything past this is refused and shrunk again.
  static const maxEncoded = 700 * 1024;

  /// Reads a picked photo and returns the two sizes, base64 encoded.
  ///
  /// The work happens off the main thread — a farmer taking a photo of a
  /// buffalo should not watch the screen freeze.
  static Future<FarmPhoto> prepare(
    File file, {
    PhotoKind kind = PhotoKind.animal,
  }) async {
    final bytes = await file.readAsBytes();
    return compute(shrinkFor, (bytes, kind));
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

/// What a photograph is of, which decides how much of it is worth keeping.
///
/// A buffalo is told apart by her markings and her face, and eight hundred
/// pixels of her is plenty. A bank slip is told apart by six digits of an
/// account number printed small, and eight hundred pixels of that is a grey
/// smudge — which makes the photograph worth nothing, since the only reason
/// it was taken is to be read three months later.
///
/// So a receipt is kept larger and at a better quality. It is still a long
/// way inside what a Firestore document holds, and it is still read only
/// when somebody actually opens it.
enum PhotoKind {
  animal(800, 60),
  receipt(1600, 78);

  const PhotoKind(this.width, this.quality);

  final int width;
  final int quality;
}

/// Shrinks a photo to the two sizes the app keeps. Top level because it runs
/// in a background isolate.
FarmPhoto shrinkPhoto(Uint8List bytes) => shrinkFor((bytes, PhotoKind.animal));

FarmPhoto shrinkFor((Uint8List, PhotoKind) work) {
  final (bytes, kind) = work;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('That file is not a picture.');
  }

  var full = decoded.width > kind.width
      ? img.copyResize(decoded, width: kind.width)
      : decoded;

  var quality = kind.quality;
  var encoded = base64Encode(img.encodeJpg(full, quality: quality));

  // Belt and braces: a picture that still will not fit is shrunk until it
  // does, rather than failing the write in front of the user.
  // Belt and braces, and gently. A photograph that will not fit is brought
  // down a step at a time rather than halved: the one picture most likely to
  // be too big is a receipt, and a receipt that has been crushed to fit is a
  // receipt nobody can read — which is the whole of its value gone.
  while (encoded.length > Photos.maxEncoded && quality > 30) {
    quality -= 8;
    full = img.copyResize(full, width: (full.width * 0.88).round());
    encoded = base64Encode(img.encodeJpg(full, quality: quality));
  }

  final thumb = img.copyResize(full, width: Photos.thumbWidth);

  return FarmPhoto(
    thumb: base64Encode(img.encodeJpg(thumb, quality: Photos.thumbQuality)),
    full: encoded,
  );
}
