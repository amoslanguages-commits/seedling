import 'dart:io';

void main() {
  final dir = Directory('c:/app/seedling/lib');
  for (final file in dir.listSync(recursive: true)) {
    if (file is File && file.path.endsWith('.dart')) {
      final content = file.readAsStringSync();
      final gradientPattern = RegExp(r'(?:Radial|Linear|Sweep)Gradient\s*\([^)]*\)', multiLine: true, dotAll: true);
      final matches = gradientPattern.allMatches(content);
      for (final match in matches) {
        final block = match.group(0)!;
        if (block.contains('colors:') && !block.contains('stops:')) {
            print('File: ' + file.path);
            print(block);
            print('---');
        }
      }
    }
  }
}
