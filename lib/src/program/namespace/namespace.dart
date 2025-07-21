/// Namespace system for Anchor programs
///
/// This module provides the core namespace functionality that enables
/// type-safe interactions with Anchor programs through IDL-generated
/// interfaces.

library;

export 'account_cache_manager.dart' hide CacheStatistics;
// Account-related utilities
export 'account_fetcher.dart';
// Individual namespace implementations
export 'account_namespace.dart';
export 'account_operations.dart'
    show
        AccountOperationsManager,
        AccountRelationship,
        AccountRelationshipType,
        AccountCreationParams,
        AccountDebugInfo;
export 'account_subscription_manager.dart' hide AccountSubscription;
export 'instruction_namespace.dart';
export 'methods_namespace.dart';
// Core namespace types and factory
export 'namespace_factory.dart';
export 'rpc_namespace.dart';
export 'simulate_namespace.dart';
export 'transaction_namespace.dart';
export 'types.dart';
export 'views_namespace.dart';
