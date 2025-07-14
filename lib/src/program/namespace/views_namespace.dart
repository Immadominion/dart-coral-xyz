import 'dart:typed_data';
import 'package:meta/meta.dart';
import 'package:coral_xyz_anchor/src/types/public_key.dart';
import 'package:coral_xyz_anchor/src/coder/main_coder.dart';
import 'package:coral_xyz_anchor/src/idl/idl.dart';
import 'package:coral_xyz_anchor/src/program/namespace/simulate_namespace.dart';
import 'package:coral_xyz_anchor/src/program/namespace/types.dart';

/// The views namespace provides read-only method calls that return data
/// without modifying blockchain state.
///
/// Views are special instruction handlers that:
/// 1. Only execute instructions that don't modify state (no writable accounts)
/// 2. Have return values defined in the IDL
/// 3. Use simulation to execute and extract return data from logs
///
/// ## Usage
///
/// ```dart
/// final result = await program.views.getPrice(market);
/// ```
class ViewsNamespace {

  ViewsNamespace._();
  final Map<String, ViewFunction> _functions = {};

  /// Build views namespace from IDL
  static ViewsNamespace build({
    required Idl idl,
    required PublicKey programId,
    required SimulateNamespace simulateNamespace,
    required Coder coder,
  }) {
    final namespace = ViewsNamespace._();

    // Create view functions for eligible instructions
    for (final instruction in idl.instructions) {
      // Check if instruction is eligible for view (read-only with return value)
      if (isViewEligible(instruction)) {
        namespace._functions[instruction.name] = ViewFunction(
          instruction: instruction,
          programId: programId,
          simulateNamespace: simulateNamespace,
          coder: coder,
        );
      }
    }

    return namespace;
  }

  /// Check if an instruction is eligible to be a view function
  @visibleForTesting
  static bool isViewEligible(IdlInstruction instruction) {
    // Must have a return type
    if (instruction.returns == null) {
      return false;
    }

    // Must not have any writable accounts
    final hasWritableAccounts = instruction.accounts.any(_accountIsWritable);

    return !hasWritableAccounts;
  }

  /// Check if an account item is writable (recursively)
  static bool _accountIsWritable(IdlInstructionAccountItem accountItem) {
    if (accountItem is IdlInstructionAccount) {
      return accountItem.writable == true;
    } else if (accountItem is IdlInstructionAccounts) {
      return accountItem.accounts.any(_accountIsWritable);
    }
    return false;
  }

  /// Get a view function by name
  ViewFunction? operator [](String name) => _functions[name];

  /// Get all view function names
  Iterable<String> get names => _functions.keys;

  /// Check if a view function exists
  bool contains(String name) => _functions.containsKey(name);

  /// Get the number of view functions
  int get length => _functions.length;

  @override
  String toString() => 'ViewsNamespace(views: ${_functions.keys.toList()})';
}

/// A view function that can be called to get read-only data from a program
class ViewFunction {

  ViewFunction({
    required IdlInstruction instruction,
    required PublicKey programId,
    required SimulateNamespace simulateNamespace,
    required Coder coder,
  })  : _instruction = instruction,
        _programId = programId,
        _simulateNamespace = simulateNamespace,
        _coder = coder;
  final IdlInstruction _instruction;
  final PublicKey _programId;
  final SimulateNamespace _simulateNamespace;
  final Coder _coder;

  /// Call the view function with the given arguments and accounts
  Future<dynamic> call(
    List<dynamic> args,
    Context<Accounts> context,
  ) async {
    // Get the simulate function for this instruction
    final simulateFn = _simulateNamespace[_instruction.name];
    if (simulateFn == null) {
      throw ArgumentError(
          'Simulate function not found for view: ${_instruction.name}',);
    }

    // Simulate the instruction
    final simulationResult = await simulateFn.call(args, context);

    // Extract return data from simulation logs
    final returnData = _extractReturnData(simulationResult);

    // Decode the return data using the instruction's return type
    if (_instruction.returns != null && returnData != null) {
      return _decodeReturnData(returnData, _instruction.returns!);
    }

    throw StateError('View function did not return data: ${_instruction.name}');
  }

  /// Extract return data from simulation logs
  Uint8List? _extractReturnData(SimulationResult simulationResult) {
    final returnPrefix = 'Program return: $_programId ';

    // Look for return log in the simulation logs
    final logs = simulationResult.logs;
    for (final log in logs) {
      if (log.startsWith(returnPrefix)) {
        final returnDataBase64 = log.substring(returnPrefix.length).trim();
        try {
          // Decode base64 return data
          return _decodeBase64(returnDataBase64);
        } catch (e) {
          throw FormatException(
              'Failed to decode return data from log: $log, error: $e',);
        }
      }
    }

    return null;
  }

  /// Decode base64 string to bytes
  Uint8List _decodeBase64(String base64) {
    // Simple base64 decoding implementation
    // In a production system, you'd use a proper base64 decoder
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final bytes = <int>[];

    var cleanBase64 = base64.replaceAll(RegExp('[^A-Za-z0-9+/]'), '');

    // Handle padding
    while (cleanBase64.length % 4 != 0) {
      cleanBase64 += '=';
    }

    for (var i = 0; i < cleanBase64.length; i += 4) {
      final chunk = cleanBase64.substring(i, i + 4);
      var value = 0;

      for (var j = 0; j < 4; j++) {
        final char = chunk[j];
        if (char == '=') break;

        final index = chars.indexOf(char);
        if (index == -1) {
          throw FormatException('Invalid base64 character: $char');
        }

        value = (value << 6) | index;
      }

      // Extract bytes (up to 3 bytes per 4-character chunk)
      if (chunk[3] != '=') bytes.add((value >> 16) & 0xFF);
      if (chunk[3] != '=' && chunk[2] != '=') bytes.add((value >> 8) & 0xFF);
      if (chunk[3] != '=' && chunk[2] != '=' && chunk[1] != '=') {
        bytes.add(value & 0xFF);
      }
    }

    return Uint8List.fromList(bytes);
  }

  /// Decode the return data using the specified return type
  dynamic _decodeReturnData(Uint8List data, String returnTypeName) {
    try {
      // Use the types coder to decode the return data based on the return type name
      if (_coder is BorshCoder) {
        final borshCoder = _coder as BorshCoder;
        return borshCoder.types.decode(returnTypeName, data);
      } else {
        throw UnsupportedError(
            'View functions require BorshCoder for return data decoding',);
      }
    } catch (e) {
      throw FormatException(
          'Failed to decode return data for ${_instruction.name}: $e',);
    }
  }

  /// Get the instruction name
  String get name => _instruction.name;

  /// Get the return type
  String? get returnType => _instruction.returns;

  /// Check if this view has a return type
  bool get hasReturnType => _instruction.returns != null;

  @override
  String toString() => 'ViewFunction(name: ${_instruction.name}, returnType: ${_instruction.returns})';
}
