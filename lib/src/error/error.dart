/// Comprehensive Anchor Error System
///
/// This module provides complete error handling for Anchor programs
/// with exact TypeScript parity and comprehensive error reporting.

// Export core error types
export 'anchor_error.dart';
export 'program_error.dart';
export 'error_constants.dart';
export 'account_errors.dart';
export 'rpc_error_parser.dart';

// Export standardized error handling framework (avoiding conflicts)
export 'error_framework.dart'
    hide
        AnchorException,
        ProviderException,
        TransactionException,
        SerializationException;
