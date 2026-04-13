import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>();

  for (final file in files) {
    if (!file.path.endsWith('.dart')) continue;
    final content = file.readAsStringSync();
    
    final gradientRegex = RegExp(r'(LinearGradient|RadialGradient|SweepGradient)\(([\s\S]*?)\)', multiLine: true);
    final matches = gradientRegex.allMatches(content);
    
    for (final match in matches) {
      final body = match.group(2) ?? '';
      if (!body.contains('stops:')) {
        // Find colors length
        final colorsMatch = RegExp(r'colors:\s*\[([\s\S]*?)\]').firstMatch(body);
        if (colorsMatch != null) {
          final colorsBody = colorsMatch.group(1) ?? '';
          final colorCount = colorsBody.split(',').where((s) => s.trim().isNotEmpty).toList().length;
          if (colorCount > 2) {
             print('MATCH: ${file.path} - ${match.group(1)} has $colorCount colors and NO stops.');
          }
        } else if (body.contains('colors:')) {
           // Case where colors is a variable like config.gradientColors
           print('MAYBE: ${file.path} - ${match.group(1)} uses dynamic colors:');
           print(body);
        }
      }
    }
  }
}
