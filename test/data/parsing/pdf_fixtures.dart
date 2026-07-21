import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:jct_mixexam/data/parsing/bidi_fixer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Generates in-memory exam PDFs for parser tests.
///
/// Real-world Hebrew exam PDFs extract in *visual* (reversed) order, so the
/// fixtures draw every Hebrew line in visual form — produced from readable
/// logical strings via [BidiFixer.fixLine], which is an involution.
class PdfFixtures {
  static PdfTrueTypeFont _font() => PdfTrueTypeFont(
        File('test/fixtures/DejaVuSans.ttf').readAsBytesSync(),
        12,
      );

  static String visual(String logical) => BidiFixer.fixLine(logical);

  /// Draws [logicalLine] the way real Hebrew exam PDFs are authored:
  /// logical text with RTL layout direction.
  static void _line(PdfPage page, PdfFont font, String logicalLine, double y,
      {double x = 40}) {
    page.graphics.drawString(
      logicalLine,
      font,
      bounds: Rect.fromLTWH(x, y, 500, 18),
      format: PdfStringFormat(
        textDirection: PdfTextDirection.rightToLeft,
        alignment: PdfTextAlignment.right,
      ),
    );
  }

  /// A purely textual exam: 2 questions, 4 bulleted answers each.
  static Uint8List textOnlyExam() {
    final document = PdfDocument();
    final font = _font();
    final page = document.pages.add();

    _line(page, font, 'שאלה מספר 1: מהו גודל המילה במעבד 8086?', 50);
    _line(page, font, 'א. 16 ביט', 75);
    _line(page, font, 'ב. 8 ביט', 95);
    _line(page, font, 'ג. 32 ביט', 115);
    _line(page, font, 'ד. 64 ביט', 135);

    _line(page, font, '2. איזה רכיב מבצע פעולות חשבון?', 180);
    _line(page, font, 'א. ALU הוא הרכיב הנכון', 205);
    _line(page, font, 'ב. זיכרון RAM', 225);
    _line(page, font, 'ג. בקר DMA', 245);
    _line(page, font, 'ד. אוגר MAR', 265);

    final bytes = Uint8List.fromList(document.saveSync());
    document.dispose();
    return bytes;
  }

  /// Mimics the quirks of real JCT exam-shell PDFs:
  ///  - "שאלה מספר X:" headers wrapped into two stacked lines
  ///  - bullets with a space ("א .")
  ///  - a page footer ("עמוד 1 מתוך 2") between questions
  ///  - a bare-numbered decoy line (instructions), which must be ignored
  ///    because the document uses explicit headers
  ///  - a question whose א bullet is lost (starts at ב) — integrity guard
  ///    must route it to the visual path
  static Uint8List realWorldStyleExam() {
    final document = PdfDocument();
    final font = _font();
    final page = document.pages.add();

    // Decoy: numbered instruction line before any question.
    _line(page, font, '1. יש לענות על כל השאלות בטופס זה', 50);

    // Q1: split header, spaced bullets.
    _line(page, font, 'שאלה', 90);
    _line(page, font, 'מספר 1:', 102);
    _line(page, font, 'מהו רכיב החישוב המרכזי?', 125);
    _line(page, font, 'א . המעבד', 150);
    _line(page, font, 'ב . הזיכרון', 170);
    _line(page, font, 'ג . הדיסק', 190);
    _line(page, font, 'ד . המסך', 210);

    // Footer noise inside the block gap.
    _line(page, font, 'עמוד 1 מתוך 1', 760);

    // Q2: the א bullet was lost by the layout — starts at ב.
    _line(page, font, 'שאלה', 300);
    _line(page, font, 'מספר 2:', 312);
    _line(page, font, 'שאלה שהתשובה הראשונה שלה אבדה', 335);
    _line(page, font, 'ב . תשובה שנייה', 360);
    _line(page, font, 'ג . תשובה שלישית', 380);
    _line(page, font, 'ד . תשובה רביעית', 400);

    final bytes = Uint8List.fromList(document.saveSync());
    document.dispose();
    return bytes;
  }

  /// An exam with one visual question (diagram between body and answers)
  /// and one pure-text question, plus one question whose answers are not
  /// extractable as text at all.
  static Uint8List visualExam() {
    final document = PdfDocument();
    final font = _font();
    final page = document.pages.add();

    // Q1: visual — body, then a 170pt-tall diagram, then the answers.
    _line(page, font, 'שאלה מספר 1: איזו טבלת קרנו מתאימה לפונקציה?', 50);
    _line(page, font, 'התבוננו בתרשים הבא:', 75);
    page.graphics.drawRectangle(
      pen: PdfPen(PdfColor(0, 0, 0), width: 2),
      bounds: const Rect.fromLTWH(150, 100, 250, 160),
    );
    _line(page, font, 'א. הטבלה הימנית העליונה', 280);
    _line(page, font, 'ב. הטבלה השמאלית העליונה', 300);
    _line(page, font, 'ג. הטבלה הימנית התחתונה', 320);
    _line(page, font, 'ד. אף תשובה אינה נכונה', 340);

    // Q2: pure text, dense.
    _line(page, font, 'שאלה מספר 2: מהי פעולת ה-XOR של 1 ו-1?', 400);
    _line(page, font, 'א. 0 תמיד', 425);
    _line(page, font, 'ב. 1 תמיד', 445);
    _line(page, font, 'ג. תלוי באוגר', 465);
    _line(page, font, 'ד. לא מוגדר', 485);

    // Q3: answers are part of a graphic — no text bullets at all.
    _line(page, font, 'שאלה מספר 3: בחרו את התרשים הנכון מבין הבאים', 540);
    page.graphics.drawRectangle(
      pen: PdfPen(PdfColor(0, 0, 0), width: 2),
      bounds: const Rect.fromLTWH(100, 570, 350, 180),
    );

    final bytes = Uint8List.fromList(document.saveSync());
    document.dispose();
    return bytes;
  }
}
