// Shrinks the bundled logo files to the size they are actually drawn at.
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  for (final (path, width) in [('assets/logo.png', 720), ('assets/mark.png', 192)]) {
    final file = File(path);
    final src = img.decodePng(file.readAsBytesSync())!;
    final out = img.copyResize(src, width: width, interpolation: img.Interpolation.cubic);
    final bytes = img.encodePng(out, level: 9);
    final before = file.lengthSync();
    file.writeAsBytesSync(bytes);
    stdout.writeln('$path  ${src.width}x${src.height} ${(before/1024).round()} KB'
        '  ->  ${out.width}x${out.height} ${(bytes.length/1024).round()} KB');
  }
}
