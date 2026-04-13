import 'dart:io';

void main() {
  final dir = Directory('c:/app/seedling/lib');
  for (final file in dir.listSync(recursive: true)) {
    if (file is File && file.path.endsWith('.dart')) {
      final content = file.readAsStringSync();
      // Match Gradients
      var lines = content.split('\n');
      for (int i=0; i<lines.length; i++) {
        if (lines[i].contains('Gradient(') || lines[i].contains('ui.Gradient.')) {
           // Gather next 25 lines to inspect for `colors:` and `colorStops:`
           String block = lines.sublist(i, (i+25 > lines.length) ? lines.length : i+25).join('\n');
           
           if (!block.contains('colors: [') && !block.contains('colors: const [')) continue;
           
           if (!block.contains('stops:')) {
             print('File: ' + file.path + ':' + (i+1).toString());
             print(lines[i]);
             print(lines[i+1]);
             print(lines[i+2]);
             print(lines[i+3]);
             print('---');
           }
        }
      }
    }
  }
}
