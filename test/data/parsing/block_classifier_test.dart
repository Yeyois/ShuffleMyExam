import 'package:flutter_test/flutter_test.dart';
import 'package:jct_mixexam/data/parsing/block_classifier.dart';
import 'package:jct_mixexam/data/parsing/geometry.dart';
import 'package:jct_mixexam/data/parsing/smart_cropper.dart';

LineBox line(double top, {double height = 14, String text = 'שורה'}) =>
    LineBox(
      text: text,
      pageIndex: 0,
      bounds: PdfBox(left: 40, top: top, width: 500, height: height),
    );

void main() {
  group('BlockClassifier', () {
    test('dense text block with 4 bullets is NOT visual', () {
      final lines = [
        line(100),
        line(118),
        line(136),
        line(154),
        line(172),
        line(190),
      ];
      expect(
        BlockClassifier.isVisual(blockLines: lines, answerBulletCount: 4),
        isFalse,
      );
    });

    test('block with a large text-free vertical gap IS visual', () {
      final lines = [
        line(100),
        line(118),
        // 150pt hole where a diagram lives.
        line(290),
        line(308),
      ];
      expect(
        BlockClassifier.isVisual(blockLines: lines, answerBulletCount: 4),
        isTrue,
      );
    });

    test('block with fewer than 2 text bullets IS visual', () {
      final lines = [line(100), line(118)];
      expect(
        BlockClassifier.isVisual(blockLines: lines, answerBulletCount: 1),
        isTrue,
      );
      expect(
        BlockClassifier.isVisual(blockLines: lines, answerBulletCount: 0),
        isTrue,
      );
    });

    test('maxVerticalGap measures the largest hole', () {
      expect(
        BlockClassifier.maxVerticalGap([line(100), line(118), line(250)]),
        closeTo(250 - (118 + 14), 0.001),
      );
      expect(BlockClassifier.maxVerticalGap([line(100)]), 0);
    });
  });

  group('SmartCropper.computeCropBoxes', () {
    test('cropped box cuts strictly above the first "א." bullet', () {
      const bulletTop = 400.0;
      final boxes = SmartCropper.computeCropBoxes(
        pageWidth: 595,
        pageHeight: 842,
        blockTop: 100,
        blockBottom: 500,
        firstBulletTop: bulletTop,
      );

      expect(boxes.cropped.bottom, lessThan(bulletTop),
          reason: 'the crop must end above the bullet so answers never leak');
      expect(boxes.full.bottom, greaterThanOrEqualTo(500));
      expect(boxes.cropped.top, boxes.full.top);
      expect(boxes.cropped.width, 595);
    });

    test('without a bullet, cropped falls back to the full block', () {
      final boxes = SmartCropper.computeCropBoxes(
        pageWidth: 595,
        pageHeight: 842,
        blockTop: 100,
        blockBottom: 500,
        firstBulletTop: null,
      );
      expect(boxes.cropped.height, boxes.full.height);
    });

    test('boxes are clamped to the page', () {
      final boxes = SmartCropper.computeCropBoxes(
        pageWidth: 595,
        pageHeight: 842,
        blockTop: 2,
        blockBottom: 841,
        firstBulletTop: 830,
      );
      expect(boxes.full.top, greaterThanOrEqualTo(0));
      expect(boxes.full.bottom, lessThanOrEqualTo(842));
    });
  });
}
