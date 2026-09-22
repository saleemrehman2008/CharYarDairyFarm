import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show GlobalKey;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../util/money.dart';
import 'statement.dart';

/// The statement as a thing you can hand somebody.
///
/// A customer asking what he owes does not want to be shown a phone. He wants
/// a page with the farm's name on it, the days laid out, and a figure at the
/// bottom — the same thing his bank sends him, which is why it is built to
/// look like that and not like the app.
///
/// Two ways out. The PDF is real text, so it can be read on anything and
/// printed without going soft; the picture is for WhatsApp, where a PDF is
/// one tap further away than most people will go.
class StatementPaper {
  StatementPaper._();

  /// The farm's own mark, as it is in the app. Loaded from the same asset the
  /// app draws, so changing the logo changes every statement printed after.
  static Future<Uint8List> _mark() async =>
      (await rootBundle.load('assets/mark.png')).buffer.asUint8List();

  static String _fileStamp(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Builds the PDF and hands it to whatever the phone shares with.
  static Future<void> sharePdf({
    required Statement statement,
    required String farmName,
    required String forWhom,
    required String period,
    num advanceHeld = 0,
  }) async {
    final doc = pw.Document();
    final mark = pw.MemoryImage(await _mark());
    final now = DateTime.now();

    // Two colours, because a statement is not a poster: the farm's blue for
    // the head and the line under the totals, and black for everything else.
    const ink = PdfColor.fromInt(0xFF16202B);
    const blue = PdfColor.fromInt(0xFF175C8C);
    const faint = PdfColor.fromInt(0xFF8B96A2);
    const rule = PdfColor.fromInt(0xFFE6EAEE);

    pw.Widget cell(String text, {bool head = false, bool right = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4.5),
          child: pw.Text(
            text,
            textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
            style: pw.TextStyle(
              fontSize: head ? 7.5 : 8.5,
              color: head ? faint : ink,
              fontWeight: head ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        );

    pw.Widget facts(String label, String value) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label.toUpperCase(),
          style: pw.TextStyle(
            fontSize: 6.5,
            color: faint,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 30, 28, 34),
        header: (context) => context.pageNumber == 1
            ? pw.SizedBox()
            : pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Text(
                  '$farmName · $forWhom · $period',
                  style: const pw.TextStyle(fontSize: 7.5, color: faint),
                ),
              ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 7.5, color: faint),
          ),
        ),
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(width: 40, height: 40, child: pw.Image(mark)),
              pw.SizedBox(width: 11),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      farmName,
                      style: pw.TextStyle(
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                        color: blue,
                      ),
                    ),
                    pw.Text(
                      statement.kind.title,
                      style: const pw.TextStyle(fontSize: 9, color: faint),
                    ),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'ISSUED',
                    style: pw.TextStyle(
                      fontSize: 6.5,
                      color: faint,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    fmtDateFull(now),
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Container(height: 1.5, color: blue),
          pw.SizedBox(height: 12),

          pw.Row(
            children: [
              pw.Expanded(child: facts('Account', forWhom)),
              pw.Expanded(child: facts('Period', period)),
              pw.Expanded(
                child: statement.showing.isEmpty
                    ? facts('Opening balance', rs(statement.opening))
                    // Narrowed, so there is no balance brought forward —
                    // what there is instead is what was left out.
                    : facts('Showing', statement.showing),
              ),
            ],
          ),
          pw.SizedBox(height: 14),

          pw.Table(
            border: const pw.TableBorder(
              horizontalInside: pw.BorderSide(color: rule, width: .6),
              bottom: pw.BorderSide(color: rule, width: .6),
            ),
            columnWidths: const {
              0: pw.FixedColumnWidth(48),
              1: pw.FlexColumnWidth(1.6),
              2: pw.FlexColumnWidth(2.6),
              3: pw.FlexColumnWidth(1.3),
              4: pw.FixedColumnWidth(62),
              5: pw.FixedColumnWidth(62),
              6: pw.FixedColumnWidth(70),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFF5F7F9),
                ),
                children: [
                  cell('DATE', head: true),
                  cell('NAME', head: true),
                  cell('DETAIL', head: true),
                  cell('ENTERED BY', head: true),
                  cell('DEBIT', head: true, right: true),
                  cell('CREDIT', head: true, right: true),
                  cell('BALANCE', head: true, right: true),
                ],
              ),
              for (final line in statement.lines)
                pw.TableRow(
                  children: [
                    cell(fmtDate(line.date)),
                    cell(line.party),
                    cell(line.detail),
                    cell(line.enteredBy),
                    cell(
                      line.debit > 0 ? groupPk(line.debit) : '',
                      right: true,
                    ),
                    cell(
                      line.credit > 0 ? groupPk(line.credit) : '',
                      right: true,
                    ),
                    cell(groupPk(line.balance), right: true),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 12),

          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                width: 250,
                padding: const pw.EdgeInsets.all(11),
                decoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFE9F3FA),
                ),
                child: pw.Column(
                  children: [
                    _sum('Total debit', rs(statement.debits)),
                    _sum('Total credit', rs(statement.credits)),
                    pw.SizedBox(height: 4),
                    pw.Container(height: 1, color: blue),
                    pw.SizedBox(height: 6),
                    _sum(
                      statement.kind.footLabel,
                      rs(statement.closing),
                      big: true,
                    ),
                    if (advanceHeld > 0) ...[
                      pw.SizedBox(height: 6),
                      _sum('Advance', rs(advanceHeld)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final safe = forWhom.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-');
    final file = File('${dir.path}/$safe-${_fileStamp(now)}.pdf');
    await file.writeAsBytes(await doc.save());
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: '$farmName — $forWhom · $period',
      ),
    );
  }

  static pw.Widget _sum(String label, String value, {bool big = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
        child: pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  fontSize: big ? 10 : 8.5,
                  fontWeight: big ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
              ),
            ),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: big ? 13 : 9,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      );

  /// The same page as a picture, for sending on WhatsApp.
  ///
  /// Painted from whatever the key is attached to, so what is sent is exactly
  /// what was on the screen — no second version of the layout to drift apart
  /// from the first.
  static Future<void> shareImage({
    required GlobalKey boundary,
    required String farmName,
    required String forWhom,
    required String period,
  }) async {
    final render =
        boundary.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (render == null) return;

    final image = await render.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return;

    final dir = await getTemporaryDirectory();
    final safe = forWhom.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-');
    final file = File('${dir.path}/$safe-${_fileStamp(DateTime.now())}.png');
    await file.writeAsBytes(bytes.buffer.asUint8List());
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: '$farmName — $forWhom · $period',
      ),
    );
  }
}
