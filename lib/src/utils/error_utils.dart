/// Error handling utilities for dart-coral-xyz.
/// Provides TypeScript-like error handling and custom error types.
library;

/// Base error class for all Anchor-related errors
class AnchorError implements Exception {
  final String message;
  final String code;
  final int? programId;
  final Map<String, dynamic>? context;

  AnchorError(
    this.message, {
    required this.code,
    this.programId,
    this.context,
  });

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('AnchorError($code): $message');
    if (programId != null) {
      buffer.write(' [Program ID: $programId]');
    }
    if (context != null && context!.isNotEmpty) {
      buffer.write(' [Context: $context]');
    }
    return buffer.toString();
  }
}

/// Program error from Solana program execution
class ProgramError extends AnchorError {
  final int errorCode;
  final String? programName;

  ProgramError(
    String message, {
    required this.errorCode,
    required String code,
    this.programName,
    int? programId,
    Map<String, dynamic>? context,
  }) : super(
          message,
          code: code,
          programId: programId,
          context: context,
        );

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('ProgramError($errorCode): $message');
    if (programName != null) {
      buffer.write(' [Program: $programName]');
    }
    return buffer.toString();
  }
}

/// IDL parsing or validation error
class IdlError extends AnchorError {
  final String? idlField;

  IdlError(
    String message, {
    this.idlField,
    Map<String, dynamic>? context,
  }) : super(
          message,
          code: 'IDL_ERROR',
          context: context,
        );

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('IdlError: $message');
    if (idlField != null) {
      buffer.write(' [Field: $idlField]');
    }
    return buffer.toString();
  }
}

/// Network or RPC related error
class NetworkError extends AnchorError {
  final int? statusCode;
  final String? endpoint;

  NetworkError(
    String message, {
    this.statusCode,
    this.endpoint,
    Map<String, dynamic>? context,
  }) : super(
          message,
          code: 'NETWORK_ERROR',
          context: context,
        );

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('NetworkError: $message');
    if (statusCode != null) {
      buffer.write(' [Status: $statusCode]');
    }
    if (endpoint != null) {
      buffer.write(' [Endpoint: $endpoint]');
    }
    return buffer.toString();
  }
}

/// Account not found error
class AccountNotFoundError extends AnchorError {
  final String? accountType;
  final String? publicKey;

  AccountNotFoundError(
    String message, {
    this.accountType,
    this.publicKey,
    Map<String, dynamic>? context,
  }) : super(
          message,
          code: 'ACCOUNT_NOT_FOUND',
          context: context,
        );

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('AccountNotFoundError: $message');
    if (accountType != null) {
      buffer.write(' [Type: $accountType]');
    }
    if (publicKey != null) {
      buffer.write(' [Key: $publicKey]');
    }
    return buffer.toString();
  }
}

/// Instruction building or execution error
class InstructionError extends AnchorError {
  final String? instructionName;
  final int? instructionIndex;

  InstructionError(
    String message, {
    this.instructionName,
    this.instructionIndex,
    Map<String, dynamic>? context,
  }) : super(
          message,
          code: 'INSTRUCTION_ERROR',
          context: context,
        );

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('InstructionError: $message');
    if (instructionName != null) {
      buffer.write(' [Instruction: $instructionName]');
    }
    if (instructionIndex != null) {
      buffer.write(' [Index: $instructionIndex]');
    }
    return buffer.toString();
  }
}

/// Simulation error
class SimulationError extends AnchorError {
  final List<String>? logs;
  final String? transactionSignature;

  SimulationError(
    String message, {
    this.logs,
    this.transactionSignature,
    Map<String, dynamic>? context,
  }) : super(
          message,
          code: 'SIMULATION_ERROR',
          context: context,
        );

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('SimulationError: $message');
    if (transactionSignature != null) {
      buffer.write(' [Signature: $transactionSignature]');
    }
    if (logs != null && logs!.isNotEmpty) {
      buffer.write(' [Logs: ${logs!.join(', ')}]');
    }
    return buffer.toString();
  }
}

/// Error utility functions
class ErrorUtils {
  /// Check if error is of specific type
  static bool isErrorOfType<T extends AnchorError>(dynamic error) {
    return error is T;
  }

  /// Get error code from any error
  static String? getErrorCode(dynamic error) {
    if (error is AnchorError) {
      return error.code;
    }
    return null;
  }

  /// Get error message with fallback
  static String getErrorMessage(dynamic error, [String? fallback]) {
    if (error is AnchorError) {
      return error.message;
    } else if (error is Exception) {
      return error.toString();
    } else if (error != null) {
      return error.toString();
    }
    return fallback ?? 'Unknown error';
  }

  /// Extract program error code from error message
  static int? extractProgramErrorCode(String errorMessage) {
    // Try to extract program error code from common error message patterns
    final patterns = [
      RegExp(r'Program failed: Custom program error: (\d+)'),
      RegExp(r'Error Code: (\d+)'),
      RegExp(r'custom program error: 0x([0-9a-fA-F]+)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(errorMessage);
      if (match != null) {
        final codeStr = match.group(1)!;
        if (pattern.pattern.contains('0x')) {
          // Hex format
          return int.tryParse(codeStr, radix: 16);
        } else {
          // Decimal format
          return int.tryParse(codeStr);
        }
      }
    }

    return null;
  }

  /// Create error from RPC response
  static AnchorError createFromRpcError(Map<String, dynamic> rpcError) {
    final message = rpcError['message'] ?? 'RPC Error';
    final data = rpcError['data'] as Map<String, dynamic>?;

    if (data != null) {
      final logs = data['logs'] as List<dynamic>?;
      final err = data['err'] as Map<String, dynamic>?;

      if (err != null) {
        // Check for instruction error
        final instructionError = err['InstructionError'] as List<dynamic>?;
        if (instructionError != null && instructionError.length >= 2) {
          final index = instructionError[0] as int?;
          final errorInfo = instructionError[1] as Map<String, dynamic>?;

          if (errorInfo != null) {
            final custom = errorInfo['Custom'] as int?;
            if (custom != null) {
              return ProgramError(
                'Program error: Custom error $custom',
                errorCode: custom,
                code: 'CUSTOM_PROGRAM_ERROR',
                context: {
                  'instructionIndex': index,
                  'logs': logs,
                },
              );
            }
          }

          return InstructionError(
            message?.toString() ?? 'Unknown error',
            instructionIndex: index,
            context: {
              'logs': logs,
              'errorInfo': errorInfo,
            },
          );
        }
      }

      return SimulationError(
        message?.toString() ?? 'RPC Error',
        logs: logs?.cast<String>(),
        context: data,
      );
    }

    return NetworkError(
      message?.toString() ?? 'RPC Error',
      statusCode: rpcError['code'] as int?,
      context: rpcError,
    );
  }

  /// TypeScript-like error throwing with stack trace
  static Never throwError(String message, [String? code]) {
    throw AnchorError(
      message,
      code: code ?? 'GENERIC_ERROR',
    );
  }

  /// TypeScript-like assertion function
  static void assertCondition(bool condition, String message) {
    if (!condition) {
      throw AnchorError(
        'Assertion failed: $message',
        code: 'ASSERTION_ERROR',
      );
    }
  }

  /// Try-catch wrapper with typed error handling
  static Future<T> tryAsync<T>(
    Future<T> Function() operation, {
    T Function(AnchorError)? onAnchorError,
    T Function(Exception)? onException,
    T Function(dynamic)? onError,
  }) async {
    try {
      return await operation();
    } on AnchorError catch (e) {
      if (onAnchorError != null) {
        return onAnchorError(e);
      }
      rethrow;
    } on Exception catch (e) {
      if (onException != null) {
        return onException(e);
      }
      rethrow;
    } catch (e) {
      if (onError != null) {
        return onError(e);
      }
      rethrow;
    }
  }

  /// Synchronous try-catch wrapper
  static T trySync<T>(
    T Function() operation, {
    T Function(AnchorError)? onAnchorError,
    T Function(Exception)? onException,
    T Function(dynamic)? onError,
  }) {
    try {
      return operation();
    } on AnchorError catch (e) {
      if (onAnchorError != null) {
        return onAnchorError(e);
      }
      rethrow;
    } on Exception catch (e) {
      if (onException != null) {
        return onException(e);
      }
      rethrow;
    } catch (e) {
      if (onError != null) {
        return onError(e);
      }
      rethrow;
    }
  }

  /// Create error chain (for debugging)
  static AnchorError createChain(
    String message,
    dynamic cause, {
    String? code,
    Map<String, dynamic>? context,
  }) {
    final chainContext = <String, dynamic>{
      if (context != null) ...context,
      'cause': cause.toString(),
      'causeType': cause.runtimeType.toString(),
    };

    return AnchorError(
      message,
      code: code ?? 'CHAINED_ERROR',
      context: chainContext,
    );
  }
}
