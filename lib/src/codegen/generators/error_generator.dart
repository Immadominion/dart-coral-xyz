/// Error class generator
///
/// This module generates typed error classes for Anchor program errors,
/// providing better error handling and debugging capabilities.
library;

import 'package:build/build.dart';
import '../../idl/idl.dart';

/// Generator for error classes
class ErrorGenerator {
  /// Creates an ErrorGenerator with the given IDL and options
  ErrorGenerator(this.idl, this.options);

  /// IDL definition
  final Idl idl;

  /// Build options
  final BuilderOptions options;

  /// Generate all error classes
  String generate() {
    final buffer = StringBuffer();

    // Generate error classes
    if (idl.errors != null && idl.errors!.isNotEmpty) {
      _generateProgramErrorClass(buffer);
    }

    return buffer.toString();
  }

  /// Generate the main program error class
  void _generateProgramErrorClass(StringBuffer buffer) {
    final programName = _toPascalCase(idl.name ?? 'Program');
    final errorClassName = '${programName}Error';

    buffer.writeln('/// Error class for ${idl.name ?? 'program'} program');
    buffer.writeln('class $errorClassName extends ProgramError {');
    buffer.writeln('  /// Creates a new $errorClassName');
    buffer.writeln('  $errorClassName._({');
    buffer.writeln('    required int code,');
    buffer.writeln('    required String message,');
    buffer.writeln('  }) : super(');
    buffer.writeln('    code: code,');
    buffer.writeln('    msg: message,');
    buffer.writeln('  );');
    buffer.writeln();

    // Generate error constants
    for (final error in idl.errors!) {
      final errorName = _toCamelCase(error.name);
      buffer.writeln('  /// ${error.name} error');
      if (error.msg != null) {
        buffer.writeln('  /// Message: ${error.msg}');
      }
      buffer.writeln(
          '  static final $errorName = $errorClassName._(code: ${error.code}, message: \'${error.msg ?? error.name}\');');
    }
    buffer.writeln();

    // Generate error lookup map
    buffer.writeln('  /// Map of error codes to error instances');
    buffer.writeln('  static final Map<int, $errorClassName> _errorMap = {');
    for (final error in idl.errors!) {
      final errorName = _toCamelCase(error.name);
      buffer.writeln('    ${error.code}: $errorName,');
    }
    buffer.writeln('  };');
    buffer.writeln();

    // Generate fromCode method
    buffer.writeln('  /// Create error from error code');
    buffer.writeln('  static $errorClassName? fromCode(int code) {');
    buffer.writeln('    return _errorMap[code];');
    buffer.writeln('  }');
    buffer.writeln();

    // Generate utility methods
    _generateUtilityMethods(buffer, errorClassName);

    buffer.writeln('}');
    buffer.writeln();
  }

  /// Generate utility methods
  void _generateUtilityMethods(StringBuffer buffer, String errorClassName) {
    // Generate toString method
    buffer.writeln('  @override');
    buffer.writeln('  String toString() {');
    buffer.writeln(
        '    return \'$errorClassName(code: \$code, message: \$message)\';');
    buffer.writeln('  }');
    buffer.writeln();

    // Generate equality methods
    buffer.writeln('  @override');
    buffer.writeln('  bool operator ==(Object other) {');
    buffer.writeln('    if (identical(this, other)) return true;');
    buffer.writeln('    if (other is! $errorClassName) return false;');
    buffer
        .writeln('    return code == other.code && message == other.message;');
    buffer.writeln('  }');
    buffer.writeln();

    // Generate hashCode method
    buffer.writeln('  @override');
    buffer.writeln('  int get hashCode {');
    buffer.writeln('    return Object.hash(code, message);');
    buffer.writeln('  }');
    buffer.writeln();

    // Generate list of all errors
    buffer.writeln('  /// List of all program errors');
    buffer.writeln('  static List<$errorClassName> get allErrors => [');
    for (final error in idl.errors!) {
      final errorName = _toCamelCase(error.name);
      buffer.writeln('    $errorName,');
    }
    buffer.writeln('  ];');
    buffer.writeln();
  }

  /// Convert string to PascalCase
  String _toPascalCase(String input) {
    return input
        .split('_')
        .map((word) => word.isNotEmpty
            ? word[0].toUpperCase() + word.substring(1).toLowerCase()
            : '')
        .join('');
  }

  /// Convert string to camelCase
  String _toCamelCase(String input) {
    final pascalCase = _toPascalCase(input);
    return pascalCase.isNotEmpty
        ? pascalCase[0].toLowerCase() + pascalCase.substring(1)
        : '';
  }
}
