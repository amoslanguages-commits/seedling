import 'package:csv/csv.dart';

void main() {
  print("CsvToListConverter exists: ${true}"); // If this compiles, it exists
  const str = "a,b\nc,d";
  try {
    // Try CsvToListConverter
    final rows1 = CsvToListConverter().convert(str);
    print("CsvToListConverter works: $rows1");
  } catch (e) {
    print("CsvToListConverter failed: $e");
  }
  
  try {
    // Try Csv().decode
    // final rows2 = Csv().decode(str); // Assuming Csv exists
    // print("Csv().decode works: $rows2");
  } catch (e) {
    print("Csv().decode failed: $e");
  }
}
