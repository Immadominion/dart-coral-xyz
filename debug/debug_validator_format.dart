import 'dart:typed_data';
import 'package:coral_xyz_anchor/src/coder/discriminator_validator.dart';

void main() {
  final validator = DiscriminatorValidator();
  final expected = Uint8List.fromList([255, 0, 15, 240, 5, 6, 7, 8]);
  final actual = Uint8List.fromList([254, 1, 16, 239, 5, 6, 7, 8]);

  final result = validator.validate(expected, actual);
  print('Error message:');
  print(result.errorMessage);

  print('\nChecking if error contains expected strings:');
  print('Contains "0xFF": ${result.errorMessage!.contains("0xFF")}');
  print('Contains "0xFE": ${result.errorMessage!.contains("0xFE")}');
  print('Contains "FF000FF0": ${result.errorMessage!.contains("FF000FF0")}');
  print('Contains "FE0110EF": ${result.errorMessage!.contains("FE0110EF")}');
}
