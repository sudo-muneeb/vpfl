import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpfl/ui/player/video_output_size.dart';

void main() {
  testWidgets('contained and cropped video origins land on physical pixels', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2500, 2500);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final (viewport, output, fit, ratio, origin) in [
      (
        const Size(1000, 760),
        const Size(1000, 563),
        BoxFit.contain,
        1.0,
        const Offset(0, 40),
      ),
      (
        const Size(1280, 680),
        const Size(1209, 680),
        BoxFit.contain,
        1.0,
        const Offset(0, 40),
      ),
      (
        const Size(800, 600),
        const Size(1000, 563),
        BoxFit.contain,
        1.25,
        const Offset(0, 40),
      ),
      (
        const Size(1000, 800),
        const Size(1423, 800),
        BoxFit.cover,
        1.0,
        const Offset(0, 40),
      ),
      (
        const Size(1000, 800),
        const Size(1422, 800),
        BoxFit.fill,
        1.0,
        const Offset(0, 40),
      ),
    ]) {
      tester.view.devicePixelRatio = ratio;
      final key = UniqueKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              Positioned(
                left: origin.dx,
                top: origin.dy,
                width: viewport.width,
                height: viewport.height,
                child: FittedBox(
                  fit: fit,
                  alignment: videoOutputAlignment(
                    viewport: viewport,
                    output: output,
                    fit: fit,
                    devicePixelRatio: ratio,
                    viewportOrigin: origin,
                  ),
                  child: SizedBox(
                    key: key,
                    // media_kit uses native texture dimensions here; the
                    // FittedBox and display DPR produce its final pixel size.
                    width: output.width,
                    height: output.height,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      final rect = tester.getRect(find.byKey(key));
      expect(
        rect.left * ratio,
        closeTo((rect.left * ratio).roundToDouble(), 0.000001),
      );
      expect(
        rect.top * ratio,
        closeTo((rect.top * ratio).roundToDouble(), 0.000001),
      );
      if (fit == BoxFit.fill) {
        expect(rect.width, closeTo(viewport.width, 0.000001));
        expect(rect.height, closeTo(viewport.height, 0.000001));
      } else {
        expect(rect.width * ratio, closeTo(output.width, 0.000001));
        expect(rect.height * ratio, closeTo(output.height, 0.000001));
      }
      final desiredCenter = origin + viewport.center(Offset.zero);
      expect(
        (rect.center.dx - desiredCenter.dx).abs() * ratio,
        lessThanOrEqualTo(0.500001),
      );
      expect(
        (rect.center.dy - desiredCenter.dy).abs() * ratio,
        lessThanOrEqualTo(0.500001),
      );
    }
  });
  test('video output follows contain, crop, stretch, and display scale', () {
    final cases =
        <
          ({
            BoxFit fit,
            Size source,
            Size viewport,
            double ratio,
            ({int width, int height}) expected,
          })
        >[
          (
            fit: BoxFit.contain,
            source: const Size(640, 360),
            viewport: const Size(1280, 680),
            ratio: 1,
            expected: (width: 1209, height: 680),
          ),
          (
            fit: BoxFit.cover,
            source: const Size(640, 360),
            viewport: const Size(1000, 800),
            ratio: 1,
            expected: (width: 1422, height: 800),
          ),
          (
            fit: BoxFit.fill,
            source: const Size(640, 360),
            viewport: const Size(1000, 800),
            ratio: 1,
            expected: (width: 1422, height: 800),
          ),
          (
            fit: BoxFit.contain,
            source: const Size(360, 640),
            viewport: const Size(600, 800),
            ratio: 1,
            expected: (width: 450, height: 800),
          ),
          (
            fit: BoxFit.contain,
            source: const Size(640, 360),
            viewport: const Size(800, 600),
            ratio: 1.25,
            expected: (width: 1000, height: 563),
          ),
          (
            fit: BoxFit.contain,
            source: const Size(640, 360),
            viewport: const Size(20000, 11250),
            ratio: 1,
            expected: (width: 8192, height: 4608),
          ),
        ];

    for (final entry in cases) {
      expect(
        videoOutputSize(
          source: entry.source,
          viewport: entry.viewport,
          fit: entry.fit,
          devicePixelRatio: entry.ratio,
        ),
        entry.expected,
      );
    }
  });
}
