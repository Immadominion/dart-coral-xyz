import 'dart:typed_data';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() {
  // Test: allows size within minimum tolerance
  // ignore: avoid_print
  print('=== Debug: Minimum Tolerance Test ===');

  final accountData = Uint8List(22); // 2 bytes short
  final structureDefinition = const AccountStructureDefinition(
    name: 'TestAccount',
    minimumSize: 16,
  );

  // ignore: avoid_print
  print('Account data size: ${accountData.length}');
  // ignore: avoid_print
  print('Structure minimum size: ${structureDefinition.minimumSize}');
  // ignore: avoid_print
  print(
    'Structure total minimum size: ${structureDefinition.totalMinimumSize}',
  );
  // ignore: avoid_print
  print('Has discriminator: ${structureDefinition.hasDiscriminator}');

  final config = const AccountSizeValidationConfig(
    minimumSizeTolerance: 4,
    strictValidation: false, // Allow tolerance to work
  );
  // ignore: avoid_print
  print('Minimum size tolerance: ${config.minimumSizeTolerance}');

  final expectedMinSize = structureDefinition.totalMinimumSize;
  final actualSize = accountData.length;
  final toleranceCheck =
      actualSize < expectedMinSize - config.minimumSizeTolerance;

  // ignore: avoid_print
  print('Expected min size: $expectedMinSize');
  // ignore: avoid_print
  print('Actual size: $actualSize');
  // ignore: avoid_print
  print(
    'Tolerance check: $actualSize < ($expectedMinSize - ${config.minimumSizeTolerance}) = $actualSize < ${expectedMinSize - config.minimumSizeTolerance} = $toleranceCheck',
  );

  final result = AccountSizeValidator.validateAccountSize(
    accountData: accountData,
    structureDefinition: structureDefinition,
    config: config,
  );

  // ignore: avoid_print
  print('Result is valid: ${result.isValid}');
  // ignore: avoid_print
  print('Error message: ${result.errorMessage}');
  // ignore: avoid_print
  print('Expected size: ${result.expectedSize}');
  // ignore: avoid_print
  print('Actual size: ${result.actualSize}');
  // ignore: avoid_print
  print('Context: ${result.context}');

  // ignore: avoid_print
  print('\n=== Debug: Maximum Tolerance Test ===');

  // Test: allows size within maximum tolerance
  final accountData2 = Uint8List(34); // 2 bytes over max (32 + 2 = 34)
  final structureDefinition2 = const AccountStructureDefinition(
    name: 'TestAccount',
    minimumSize: 16,
    maximumSize: 24, // 32 total with discriminator
  );

  // ignore: avoid_print
  print('Account data size: ${accountData2.length}');
  // ignore: avoid_print
  print('Structure minimum size: ${structureDefinition2.minimumSize}');
  // ignore: avoid_print
  print('Structure maximum size: ${structureDefinition2.maximumSize}');
  // ignore: avoid_print
  print(
    'Structure total minimum size: ${structureDefinition2.totalMinimumSize}',
  );
  print(
      'Structure total maximum size: ${structureDefinition2.totalMaximumSize}',);

  final config2 = const AccountSizeValidationConfig(maximumSizeTolerance: 4);
  print('Maximum size tolerance: ${config2.maximumSizeTolerance}');

  final expectedMaxSize = structureDefinition2.totalMaximumSize!;
  final actualSize2 = accountData2.length;
  final maxToleranceCheck =
      actualSize2 > expectedMaxSize + config2.maximumSizeTolerance;

  print('Expected max size: $expectedMaxSize');
  print('Actual size: $actualSize2');
  print(
      'Max tolerance check: $actualSize2 > ($expectedMaxSize + ${config2.maximumSizeTolerance}) = $actualSize2 > ${expectedMaxSize + config2.maximumSizeTolerance} = $maxToleranceCheck',);

  final result2 = AccountSizeValidator.validateAccountSize(
    accountData: accountData2,
    structureDefinition: structureDefinition2,
    config: config2,
  );

  print('Result is valid: ${result2.isValid}');
  print('Error message: ${result2.errorMessage}');
  print('Expected size: ${result2.expectedSize}');
  print('Actual size: ${result2.actualSize}');
  print('Context: ${result2.context}');
}
