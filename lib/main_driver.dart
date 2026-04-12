import 'package:flutter_driver/driver_extension.dart';
import 'package:seedling/main.dart' as app;

void main() {
  // Enable the extension that allows the 'flutter_driver' tool
  // to communicate with the running application.
  enableFlutterDriverExtension();

  // Then start the actual app
  app.main();
}
