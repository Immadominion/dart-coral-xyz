/// Comprehensive Anchor Error System
///
/// This module provides complete error handling for Anchor programs
/// with exact TypeScript parity and comprehensive error reporting.
library;

// Export account-specific errors (preferred over duplicates in anchor_error.dart)
export 'account_errors.dart';

// Export core error types (excluding duplicates)
export 'anchor_error.dart' hide AccountDiscriminatorMismatchError, ProgramError;
export 'error_constants.dart';

// Export enhanced error classes for production-ready error handling
export 'enhanced_error_classes.dart'
    hide AccountDiscriminatorMismatchError, ConstraintError, InstructionError;

// Export error context and reporting system
export 'error_context.dart';

// Export specialized logging for Anchor operations
export 'anchor_logging.dart';

// Export error recovery and retry system
export 'error_recovery.dart';

// Export error monitoring and metrics
export 'error_monitoring.dart';

// Export error validation and testing utilities
export 'error_validation.dart';

// Export production error handler integration
export 'production_error_handler.dart';

// Export standardized error handling framework (avoiding conflicts)
export 'error_framework.dart'
    hide
        AnchorException,
        ProviderException,
        TransactionException,
        SerializationException;

// Export program-specific errors (excluding duplicates)
export 'program_error.dart';
export 'rpc_error_parser.dart';
