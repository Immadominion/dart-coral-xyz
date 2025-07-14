/// RPC error handling utilities
///
/// This module provides exception classes and error handling utilities
/// for Solana RPC operations.

library;

/// Base exception for RPC-related errors
class RpcException implements Exception {

  const RpcException(
    this.message, {
    this.code,
    this.data,
  });
  /// The error message
  final String message;

  /// Optional error code from the RPC response
  final int? code;

  /// Optional additional error data
  final dynamic data;

  @override
  String toString() {
    if (code != null) {
      return 'RpcException($code): $message';
    }
    return 'RpcException: $message';
  }
}

/// Exception for connection-related errors
class ConnectionException extends RpcException {
  const ConnectionException(
    super.message, {
    super.code,
    super.data,
  });
}

/// Exception for transaction-related errors
class TransactionException extends RpcException {
  const TransactionException(
    super.message, {
    super.code,
    super.data,
  });
}

/// Exception for account-related errors
class AccountException extends RpcException {
  const AccountException(
    super.message, {
    super.code,
    super.data,
  });
}

/// Exception for timeout errors
class TimeoutException extends RpcException {
  const TimeoutException(
    super.message, {
    super.code,
    super.data,
  });
}

/// Exception for retry exhaustion
class RetryExhaustedException extends RpcException {

  const RetryExhaustedException(
    super.message,
    this.attempts, {
    super.code,
    super.data,
  });
  /// Number of attempts made
  final int attempts;

  @override
  String toString() => 'RetryExhaustedException: $message after $attempts attempts';
}
