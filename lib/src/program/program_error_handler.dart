/// Unified error handling system for Program operations
///
/// This module provides a unified error handling system that matches TypeScript
/// Anchor's error handling patterns and provides consistent error types across
/// all Program operations.
library;

import 'package:coral_xyz_anchor/src/error/anchor_error.dart';
import 'package:coral_xyz_anchor/src/error/program_error.dart' as programErrorLib;
import 'package:coral_xyz_anchor/src/error/account_errors.dart' hide AccountDiscriminatorMismatchError;
import 'package:coral_xyz_anchor/src/error/anchor_error.dart' show AccountDiscriminatorMismatchError;
import 'package:coral_xyz_anchor/src/types/public_key.dart';

/// Unified Program error for all Program operations
///
/// This class provides a consistent interface for creating and handling
/// errors that occur during Program operations, matching TypeScript's
/// error handling patterns.
class ProgramOperationError extends AnchorError {

  ProgramOperationError({
    required this.operation,
    required String message,
    required int code,
    this.context,
    this.cause,
    List<String>? logs,
  }) : super(
          error: ErrorInfo(
            errorCode: ErrorCode(code: 'ProgramOperationError', number: code),
            errorMessage: message,
          ),
          errorLogs: logs ?? [],
          logs: logs ?? [],
        );

  /// Create an error for IDL fetching operations
  factory ProgramOperationError.idlFetch({
    required PublicKey programId,
    required String reason,
    dynamic cause,
  }) {
    return ProgramOperationError(
      operation: 'fetchIdl',
      message:
          'Failed to fetch IDL for program ${programId.toBase58()}: $reason',
      code: 6000, // Custom error code for IDL operations
      context: {
        'programId': programId.toBase58(),
        'reason': reason,
      },
      cause: cause,
    );
  }

  /// Create an error for method execution operations
  factory ProgramOperationError.methodExecution({
    required String methodName,
    required String reason,
    Map<String, dynamic>? context,
    dynamic cause,
    List<String>? logs,
  }) {
    return ProgramOperationError(
      operation: 'methodExecution',
      message: 'Failed to execute method $methodName: $reason',
      code: 6001, // Custom error code for method execution
      context: {
        'methodName': methodName,
        'reason': reason,
        ...?context,
      },
      cause: cause,
      logs: logs,
    );
  }

  /// Create an error for instruction building operations
  factory ProgramOperationError.instructionBuilding({
    required String instructionName,
    required String reason,
    Map<String, dynamic>? context,
    dynamic cause,
  }) {
    return ProgramOperationError(
      operation: 'instructionBuilding',
      message: 'Failed to build instruction $instructionName: $reason',
      code: 6002, // Custom error code for instruction building
      context: {
        'instructionName': instructionName,
        'reason': reason,
        ...?context,
      },
      cause: cause,
    );
  }

  /// Create an error for account operations
  factory ProgramOperationError.accountOperation({
    required String accountType,
    required String operation,
    required String reason,
    PublicKey? accountAddress,
    dynamic cause,
  }) {
    return ProgramOperationError(
      operation: 'accountOperation',
      message: 'Failed to $operation account $accountType: $reason',
      code: 6003, // Custom error code for account operations
      context: {
        'accountType': accountType,
        'operation': operation,
        'reason': reason,
        if (accountAddress != null) 'accountAddress': accountAddress.toBase58(),
      },
      cause: cause,
    );
  }

  /// Create an error for simulation operations
  factory ProgramOperationError.simulation({
    required String reason,
    Map<String, dynamic>? context,
    dynamic cause,
    List<String>? logs,
  }) {
    return ProgramOperationError(
      operation: 'simulation',
      message: 'Transaction simulation failed: $reason',
      code: 6004, // Custom error code for simulation
      context: {
        'reason': reason,
        ...?context,
      },
      cause: cause,
      logs: logs,
    );
  }

  /// Create an error for transaction operations
  factory ProgramOperationError.transaction({
    required String reason,
    Map<String, dynamic>? context,
    dynamic cause,
    List<String>? logs,
  }) {
    return ProgramOperationError(
      operation: 'transaction',
      message: 'Transaction failed: $reason',
      code: 6005, // Custom error code for transactions
      context: {
        'reason': reason,
        ...?context,
      },
      cause: cause,
      logs: logs,
    );
  }
  /// The operation that caused the error
  final String operation;

  /// Additional context about the error
  final Map<String, dynamic>? context;

  /// The underlying cause of the error
  final dynamic cause;

  /// Get the error code for this operation error
  int get code => error.errorCode.number;

  /// Get the error message for this operation error
  String get msg => error.errorMessage;

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('ProgramOperationError: $msg');
    buffer.writeln('Operation: $operation');
    buffer.writeln('Code: $code');

    if (context != null && context!.isNotEmpty) {
      buffer.writeln('Context:');
      for (final entry in context!.entries) {
        buffer.writeln('  ${entry.key}: ${entry.value}');
      }
    }

    if (cause != null) {
      buffer.writeln('Caused by: $cause');
    }

    if (logs.isNotEmpty) {
      buffer.writeln('Transaction logs:');
      for (final log in logs) {
        buffer.writeln('  $log');
      }
    }

    return buffer.toString();
  }
}

/// Error handler utilities for Program operations
class ProgramErrorHandler {
  /// Wrap an operation with unified error handling
  ///
  /// This method provides a consistent way to handle errors that occur
  /// during Program operations, converting various error types to
  /// ProgramOperationError instances.
  static Future<T> wrapOperation<T>(
    String operationName,
    Future<T> Function() operation, {
    Map<String, dynamic>? context,
  }) async {
    try {
      return await operation();
    } on ProgramOperationError {
      rethrow; // Already wrapped
    } on AccountDiscriminatorMismatchError catch (e) {
      throw ProgramOperationError.accountOperation(
        accountType: 'unknown',
        operation: 'decode',
        reason: 'Discriminator mismatch: ${e.toString()}',
        cause: e,
      );
    } on AccountNotMutableError catch (e) {
      throw ProgramOperationError.accountOperation(
        accountType: 'unknown',
        operation: 'access',
        reason: 'Account not mutable: ${e.toString()}',
        cause: e,
      );
    } on AnchorError catch (e) {
      throw ProgramOperationError(
        operation: operationName,
        message: e.message,
        code: e.errorCode.number,
        context: context,
        cause: e,
        logs: e.logs,
      );
    } catch (e) {
      throw ProgramOperationError(
        operation: operationName,
        message: 'Unexpected error during $operationName: ${e.toString()}',
        code: 6999, // Generic error code
        context: {
          'originalErrorType': e.runtimeType.toString(),
          ...?context,
        },
        cause: e,
      );
    }
  }

  /// Handle RPC errors specifically
  static ProgramOperationError handleRpcError(
    String operation,
    dynamic error, {
    Map<String, dynamic>? context,
  }) {
    if (error is Map<String, dynamic>) {
      final code = error['code'] as int? ?? 6999;
      final message = error['message'] as String? ?? 'RPC error';
      final data = error['data'] as Map<String, dynamic>?;

      return ProgramOperationError(
        operation: operation,
        message: 'RPC error during $operation: $message',
        code: code,
        context: {
          'rpcError': error,
          ...?context,
          if (data != null) 'rpcData': data,
        },
        cause: error,
      );
    }

    return ProgramOperationError(
      operation: operation,
      message: 'Unknown RPC error during $operation: ${error.toString()}',
      code: 6999,
      context: context,
      cause: error,
    );
  }

  /// Parse transaction logs for program errors
  static List<programErrorLib.ProgramError> parseTransactionLogs(
    List<String> logs,
    Map<int, String> idlErrors,
  ) {
    final errors = <programErrorLib.ProgramError>[];

    for (final log in logs) {
      final programError = programErrorLib.ProgramError.parse(log, idlErrors);
      if (programError != null) {
        errors.add(programError);
      }
    }

    return errors;
  }

  /// Create a user-friendly error message from a ProgramOperationError
  static String createUserMessage(ProgramOperationError error) {
    final operation = _humanizeOperation(error.operation);

    switch (error.code) {
      case 6000:
        return 'Could not load program interface. Please check that the program '
            'has been deployed and the IDL is available.';
      case 6001:
        final methodName = error.context?['methodName'] ?? 'unknown';
        return 'Failed to execute $methodName. Please check your arguments and '
            'account permissions.';
      case 6002:
        final instructionName = error.context?['instructionName'] ?? 'unknown';
        return 'Could not build $instructionName instruction. Please verify '
            'your accounts and parameters.';
      case 6003:
        final accountType = error.context?['accountType'] ?? 'account';
        return 'Account operation failed for $accountType. Please check '
            'account permissions and state.';
      case 6004:
        return 'Transaction simulation failed. The transaction would fail '
            'if submitted to the network.';
      case 6005:
        return 'Transaction failed. Please check the transaction logs for '
            'specific error details.';
      default:
        return 'Operation $operation failed: ${error.msg}';
    }
  }

  static String _humanizeOperation(String operation) {
    switch (operation) {
      case 'fetchIdl':
        return 'loading program interface';
      case 'methodExecution':
        return 'method execution';
      case 'instructionBuilding':
        return 'instruction building';
      case 'accountOperation':
        return 'account operation';
      case 'simulation':
        return 'transaction simulation';
      case 'transaction':
        return 'transaction';
      default:
        return operation;
    }
  }
}
