import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>();

  for (final file in files) {
    if (!file.path.endsWith('.dart')) continue;
    final content = file.readAsStringSync();
    
    // Simple regex to find Linear/Radial/Sweep gradients
    final gradientRegex = RegExp(r'(LinearGradient|RadialGradient|SweepGradient)\(([\s\S]*?)\)', multiLine: true);
    final matches = gradientRegex.allMatches(content);
    
    for (final match in matches) {
      final type = match.group(1);
      final body = match.group(2) ?? '';
      
      // Count colors. This is a bit naive but should work for most cases.
      // We look for 'colors: [' followed by items until ']'
      final colorsMatch = RegExp(r'colors:\s*\[([\s\S]*?)\]').firstMatch(body);
      if (colorsMatch != null) {
        final colorsBody = colorsMatch.group(1) ?? '';
        final colors = colorsBody.split(',').where((s) => s.trim().isNotEmpty).toList();
        
        if (colors.length > 2) {
          // Check if stops are present
          if (!body.contains('stops:')) {
            print('POTENTIAL CRASH in ${file.path}: $type with ${colors.length} colors and NO stops.');
            // Print a snippet for context
            final lineNum = content.substring(0, match.start).split('\n').length;
            print('Line $lineNum');
          }
        }
      }
    }
  }
}
