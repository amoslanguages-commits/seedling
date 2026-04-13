import 'package:csv/csv.dart';

void main() {
  const str = "a,b\nc,d";
  try {
    final rows = csv.decode(str); 
    print("csv.decode works: $rows");
  } catch (e) {
    print("Error: $e");
  }
}
