# Coral XYZ Anchor Dart SDK - Code Style Guide

## Overview

This document establishes consistent coding standards for the Coral XYZ Anchor Dart SDK to ensure maintainability, readability, and consistency across all modules.

## General Principles

1. **Clarity over Cleverness**: Code should be self-documenting and easy to understand
2. **Consistency**: Follow established patterns throughout the codebase
3. **Type Safety**: Leverage Dart's type system for better error prevention
4. **Performance**: Consider performance implications of design decisions
5. **Testability**: Write code that is easy to test and validate

## File Organization

### Directory Structure

```
lib/
├── src/                    # Private implementation
│   ├── types/             # Core type definitions
│   ├── provider/          # Connection and provider management
│   ├── program/           # Program interaction logic
│   ├── coder/             # Serialization/deserialization
│   ├── event/             # Event system
│   ├── utils/             # Utility functions
│   └── ...
├── coral_xyz_anchor.dart  # Public API exports
test/
├── unit/                  # Unit tests
├── integration/           # Integration tests
└── ...
```

### File Naming

- Use snake_case for file names: `event_subscription_manager.dart`
- Match class names with file names: `EventSubscriptionManager` in `event_subscription_manager.dart`
- Use descriptive names that indicate file purpose

## Code Style

### Imports

```dart
// Standard library imports first
import 'dart:async';
import 'dart:typed_data';

// Package imports second
import 'package:test/test.dart';
import 'package:meta/meta.dart';

// Relative imports last
import '../types/public_key.dart';
import 'event_types.dart';
```

### Class Structure

````dart
/// Class documentation describing purpose and usage.
///
/// Example:
/// ```dart
/// final manager = EventSubscriptionManager(connection);
/// await manager.subscribe(programId, callback);
/// ```
class EventSubscriptionManager {
  // Private fields first
  final Connection _connection;
  final Map<String, StreamSubscription> _subscriptions = {};

  // Public fields
  final EventSubscriptionConfig config;

  // Constructor
  EventSubscriptionManager(
    this._connection, {
    this.config = const EventSubscriptionConfig(),
  });

  // Public methods
  Future<String> subscribe(/* parameters */) async {
    // Implementation
  }

  // Private methods
  void _cleanup() {
    // Implementation
  }
}
````

### Method Structure

```dart
/// Brief description of what the method does.
///
/// [parameter] Description of parameter
///
/// Returns description of return value.
///
/// Throws [ExceptionType] when condition occurs.
Future<Result> methodName(
  String requiredParam,
  int anotherParam, {
  bool optionalParam = false,
  String? nullableParam,
}) async {
  // Validation first
  ArgumentError.checkNotNull(requiredParam, 'requiredParam');
  if (anotherParam < 0) {
    throw ArgumentError.value(anotherParam, 'anotherParam', 'Must be non-negative');
  }

  try {
    // Main logic
    final result = await _performOperation(requiredParam, anotherParam);

    // Return with validation
    return result ?? _getDefaultResult();

  } on SpecificException catch (e) {
    // Specific error handling
    throw AnchorException('Operation failed: ${e.message}', cause: e);
  } catch (e) {
    // Generic error handling
    throw AnchorException('Unexpected error in methodName', cause: e);
  }
}
```

## Error Handling

### Exception Hierarchy

```dart
// Base exception for all Anchor-related errors
abstract class AnchorException implements Exception {
  const AnchorException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'AnchorException: $message';
}

// Specific exception types
class ProviderException extends AnchorException {
  const ProviderException(super.message, {super.cause});
}

class ConnectionException extends AnchorException {
  const ConnectionException(super.message, {super.cause, this.endpoint});

  final String? endpoint;
}
```

### Error Handling Patterns

```dart
// Input validation
void _validateInput(String value) {
  ArgumentError.checkNotNull(value, 'value');
  if (value.isEmpty) {
    throw ArgumentError.value(value, 'value', 'Cannot be empty');
  }
}

// Operation with error context
Future<Result> performOperation() async {
  try {
    return await _doOperation();
  } on NetworkException catch (e) {
    throw ConnectionException(
      'Network operation failed',
      cause: e,
      endpoint: _endpoint,
    );
  } catch (e) {
    throw AnchorException('Operation failed unexpectedly', cause: e);
  }
}

// Resource cleanup
Future<void> cleanup() async {
  try {
    await _closeConnections();
  } catch (e) {
    // Log but don't throw in cleanup
    print('Warning: Error during cleanup: $e');
  }
}
```

## Documentation Standards

### Class Documentation

````dart
/// Manages subscription to program events with filtering and processing.
///
/// The [EventSubscriptionManager] provides a high-level interface for
/// subscribing to Solana program events with automatic filtering,
/// deserialization, and error handling.
///
/// ## Features
/// - Automatic event filtering by type or account
/// - Built-in retry logic for failed subscriptions
/// - Metrics collection and monitoring
/// - Memory-efficient event processing
///
/// ## Usage
/// ```dart
/// final manager = EventSubscriptionManager(connection);
/// final subscription = await manager.subscribe(
///   programId,
///   config: EventSubscriptionConfig(
///     filters: [EventFilter.byType('Transfer')],
///   ),
///   callback: (event) => print('Event: $event'),
/// );
/// ```
///
/// ## Error Handling
/// The manager automatically handles connection errors and implements
/// exponential backoff for reconnection attempts. Custom error handlers
/// can be provided through [EventSubscriptionConfig.onError].
class EventSubscriptionManager {
  // Implementation
}
````

### Method Documentation

````dart
/// Subscribes to events from the specified program.
///
/// Creates a new subscription that will receive events from [programId]
/// according to the filters specified in [config]. The [callback] will
/// be invoked for each matching event.
///
/// [programId] The program to subscribe to events from
/// [config] Subscription configuration including filters and options
/// [callback] Function to call when events are received
///
/// Returns a subscription ID that can be used to unsubscribe.
///
/// Throws [ConnectionException] if unable to establish connection.
/// Throws [ArgumentError] if [programId] is invalid.
///
/// Example:
/// ```dart
/// final subscriptionId = await manager.subscribe(
///   PublicKey.fromBase58('program_id'),
///   config: EventSubscriptionConfig(
///     commitment: Commitment.confirmed,
///     filters: [EventFilter.byType('Transfer')],
///   ),
///   callback: (event) {
///     print('Transfer: ${event.data}');
///   },
/// );
/// ```
Future<String> subscribe(
  PublicKey programId, {
  required EventSubscriptionConfig config,
  required EventCallback callback,
}) async {
  // Implementation
}
````

## Testing Standards

### Test Structure

```dart
import 'package:test/test.dart';
import 'package:coral_xyz_anchor/coral_xyz_anchor.dart';

void main() {
  group('EventSubscriptionManager', () {
    late EventSubscriptionManager manager;
    late MockConnection connection;

    setUp(() {
      connection = MockConnection();
      manager = EventSubscriptionManager(connection);
    });

    tearDown(() async {
      await manager.dispose();
    });

    group('subscribe', () {
      test('should create subscription with valid parameters', () async {
        // Arrange
        final programId = PublicKey.fromBase58('valid_program_id');
        final config = EventSubscriptionConfig();
        var eventReceived = false;

        // Act
        final subscriptionId = await manager.subscribe(
          programId,
          config: config,
          callback: (event) => eventReceived = true,
        );

        // Assert
        expect(subscriptionId, isNotEmpty);
        expect(manager.isSubscribed(subscriptionId), isTrue);
      });

      test('should throw ArgumentError for invalid program ID', () async {
        // Act & Assert
        expect(
          () => manager.subscribe(
            PublicKey.fromBase58('invalid'),
            config: EventSubscriptionConfig(),
            callback: (event) {},
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });
  });
}
```

### Mock Objects

```dart
class MockConnection implements Connection {
  @override
  Future<LatestBlockhash> getLatestBlockhash() async {
    return LatestBlockhash(
      blockhash: 'mock_blockhash',
      lastValidBlockHeight: 12345,
    );
  }

  // Implement other required methods
}
```

## Performance Guidelines

### Memory Management

```dart
// Use const constructors where possible
const config = EventSubscriptionConfig(
  commitment: Commitment.confirmed,
);

// Dispose of resources properly
class ResourceManager {
  StreamSubscription? _subscription;

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}

// Use efficient data structures
final Map<String, EventSubscription> _subscriptions = <String, EventSubscription>{};
```

### Async Patterns

```dart
// Prefer async/await over then()
Future<Result> goodPattern() async {
  final data = await fetchData();
  return processData(data);
}

// Use Stream.listen() for continuous data
void setupEventStream() {
  _eventStream.listen(
    (event) => _processEvent(event),
    onError: (error) => _handleError(error),
    onDone: () => _cleanup(),
  );
}

// Use completer for complex async operations
Future<Result> complexOperation() {
  final completer = Completer<Result>();

  _startOperation((result) {
    if (result.isSuccess) {
      completer.complete(result.value);
    } else {
      completer.completeError(result.error);
    }
  });

  return completer.future;
}
```

## Code Review Checklist

### Before Submitting

- [ ] All methods have comprehensive documentation
- [ ] Error handling follows established patterns
- [ ] Tests cover all public methods and error cases
- [ ] No direct src/ imports in test files
- [ ] Performance implications considered
- [ ] Memory leaks prevented (proper disposal)
- [ ] Type safety maximized (avoid dynamic where possible)

### Review Criteria

- [ ] Code follows established patterns
- [ ] Documentation is clear and complete
- [ ] Error messages are helpful to developers
- [ ] Tests are comprehensive and meaningful
- [ ] Performance is appropriate for use case
- [ ] Breaking changes are documented
- [ ] Public API changes maintain backward compatibility

## Maintenance Guidelines

### Deprecation Process

```dart
/// Creates a connection to the Solana cluster.
///
/// This method is deprecated. Use [Connection.create] instead.
@Deprecated('Use Connection.create() instead. Will be removed in v2.0.0')
Connection createConnection(String endpoint) {
  return Connection.create(endpoint);
}
```

### Version Compatibility

- Maintain backward compatibility within major versions
- Use semantic versioning for releases
- Document breaking changes in CHANGELOG.md
- Provide migration guides for major version updates

### Code Organization

- Keep related functionality together
- Extract common patterns into utilities
- Minimize dependencies between modules
- Use dependency injection for testability

This style guide ensures consistent, maintainable, and high-quality code across the entire Coral XYZ Anchor Dart SDK.
