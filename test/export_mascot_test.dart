import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/core/colors.dart';
import 'package:seedling/widgets/mascot.dart';

void main() {
  testWidgets('Export Mascot to PNG', (tester) async {
    const double size = 1024;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Circular background
    final bgPaint = Paint()..color = SeedlingColors.background;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, bgPaint);

    // Use the public export function
    const mascotWidth = size * 0.72;
    const mascotHeight = mascotWidth * 1.45;

    canvas.save();
    canvas.translate(
      (size - mascotWidth) / 2,
      (size - mascotHeight) / 2 + size * 0.04,
    );

    SeedlingMascot.paintForExport(
      canvas,
      const Size(mascotWidth, mascotHeight),
      state: MascotState.idle,
    );

    canvas.restore();

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    final file = File('assets/icons/app_icon.png');
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    file.writeAsBytesSync(bytes);

    debugPrint(
      'Successfully exported app_icon.png to assets/icons/app_icon.png',
    );
  });
}
