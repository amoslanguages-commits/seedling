import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedling/widgets/mascot.dart';
import 'package:seedling/core/colors.dart';

void main() {
  test('generate app icon', () async {
    const sizeContext = Size(1024, 1024);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Offset.zero & sizeContext);

    // 1. Draw the actual app background exactly
    final bgPaint = Paint()..color = SeedlingColors.background;
    canvas.drawRect(Offset.zero & sizeContext, bgPaint);

    // 2. Determine best fit for mascot (66% safe zone compliance for adaptive icons)
    final mascotW = 675.0; 
    final mascotH = mascotW * 1.35; // Aspect ratio of the mascot widget
    
    canvas.save();
    // Centering precisely within the 1024x1024 canvas
    canvas.translate(
      (sizeContext.width - mascotW) / 2, 
      (sizeContext.height - mascotH) / 2 + 30 // Reduced offset to keep it centered in safe zone
    );
    
    SeedlingMascot.paintForExport(
      canvas, 
      Size(mascotW, mascotH), 
      state: MascotState.happy,
    );
    canvas.restore();

    final picture = recorder.endRecording();
    final image = await picture.toImage(sizeContext.width.toInt(), sizeContext.height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    final file = File('assets/icons/app_icon.png');
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    file.writeAsBytesSync(pngBytes);
    print('SUCCESS: Icon saved to ${file.path}');
  });
}
