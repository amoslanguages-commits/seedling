import 'dart:io';

void main() {
  final dir = Directory('c:/app/seedling/lib');
  int badGradients = 0;
  for (final file in dir.listSync(recursive: true)) {
    if (file is File && file.path.endsWith('.dart')) {
      final content = file.readAsStringSync();
      // Match Gradients with parameters
      final gradRegex = RegExp(r'(?:Radial|Linear|Sweep)Gradient\s*\(([^)]+)\)', multiLine: true, dotAll: true);
      final matches = gradRegex.allMatches(content);
      
      for (final match in matches) {
        final body = match.group(1)!;
        if (body.contains('colors:') && !body.contains('stops:')) {
            // Check color count
            final colorsPart = RegExp(r'colors:\s*(?:const\s*)?\[([^\]]*)\]', dotAll: true).firstMatch(body);
            if (colorsPart != null) {
              final colorItems = colorsPart.group(1)!.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
              if (colorItems.length != 2 && colorItems.length > 0) {
                print('INVALID GRADIENT: ' + file.path);
                print('Count: ' + colorItems.length.toString());
                print(match.group(0));
                print('---');
                badGradients++;
              }
            }
        }
      }
      
      // Also check ui.Gradient positional
      final uiGradRegex = RegExp(r'ui\.Gradient\.(?:linear|radial|sweep)\s*\(([^)]+)\)', multiLine: true, dotAll: true);
      final uiMatches = uiGradRegex.allMatches(content);
      for (final match in uiMatches) {
        final body = match.group(1)!;
        final listRegex = RegExp(r'\[([^\]]*)\]');
        final lists = listRegex.allMatches(body).toList();
        if (lists.isNotEmpty) {
           // Heuristic: colors is the first list unless it's very short (like a point)
           // But check if it has a second list for stops
           if (lists.length == 1) {
              final items = lists[0].group(1)!.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
              if (items.length != 2 && items.length > 0) {
                 print('INVALID UI GRADIENT: ' + file.path);
                 print('Count: ' + items.length.toString());
                 print(match.group(0));
                 print('---');
                 badGradients++;
              }
           }
        }
      }
    }
  }
  print('Total bad gradients found: ' + badGradients.toString());
}
