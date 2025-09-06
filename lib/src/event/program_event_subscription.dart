/// Advanced Program Event Subscription using espresso-cash SubscriptionClient
///
/// This module provides Phase 4: Advanced Features Integration for complete
/// TypeScript SDK parity with espresso-cash battle-tested subscription patterns.
library;

import 'dart:async';
import 'package:solana/dto.dart' as dto;
import 'package:solana/src/subscription_client/logs_filter.dart';
import '../types/public_key.dart';
import '../types/commitment.dart';
import '../provider/anchor_provider.dart';
import '../coder/main_coder.dart';
import 'types.dart';
import 'event_parser.dart';

/// Program event subscription using espresso-cash SubscriptionClient patterns
///
/// Provides real-time event monitoring with TypeScript SDK compatibility:
/// - Numeric listener IDs matching TypeScript exactly
/// - Espresso-cash SubscriptionClient integration
/// - Production-ready event filtering and parsing
/// - Automatic subscription lifecycle management
class ProgramEventSubscription {
  ProgramEventSubscription({
    required PublicKey programId,
    required AnchorProvider provider,
    required BorshCoder coder,
  })  : _programId = programId,
        _provider = provider,
        _eventParser = EventParser(programId, coder);

  /// Program ID for event subscriptions
  final PublicKey _programId;

  /// Network and wallet provider with espresso-cash integration
  final AnchorProvider _provider;

  /// Event parser for processing logs
  final EventParser _eventParser;

  /// Maps event listener id to [event-name, callback].
  final Map<int, List<dynamic>> _eventCallbacks = <int, List<dynamic>>{};

  /// Maps event name to all listeners for the event.
  final Map<String, List<int>> _eventListeners = <String, List<int>>{};

  /// The next listener id to allocate (TypeScript compatibility).
  int _listenerIdCount = 0;

  /// Active subscription streams by filter
  final Map<String, StreamSubscription<dto.Logs>> _subscriptions = {};

  /// Subscription client for espresso-cash integration
  StreamSubscription<dto.Logs>? _primarySubscription;

  /// Statistics for monitoring
  int _totalEvents = 0;
  int _parseErrors = 0;
  int _filterMatches = 0;
  DateTime? _lastEvent;

  /// Add event listener - TypeScript SDK compatible
  ///
  /// Returns numeric listener ID synchronously matching TypeScript behavior.
  /// Uses espresso-cash SubscriptionClient for production-ready subscription.
  int addEventListener<T>(
    String eventName,
    EventCallback<T> callback, {
    Commitment? commitment,
  }) {
    final int listener = _listenerIdCount;
    _listenerIdCount += 1;

    // Store the listener into the event map.
    if (!_eventListeners.containsKey(eventName)) {
      _eventListeners[eventName] = <int>[];
    }
    _eventListeners[eventName] = (_eventListeners[eventName] ?? <int>[])
      ..add(listener);

    // Store the callback into the listener map.
    _eventCallbacks[listener] = [eventName, callback];

    // Ensure primary subscription exists
    _ensurePrimarySubscription(commitment);

    return listener;
  }

  /// Remove event listener - TypeScript SDK compatible
  Future<void> removeEventListener(int listener) async {
    // Get the callback.
    final callback = _eventCallbacks[listener];
    if (callback == null) {
      throw ArgumentError('Event listener $listener doesn\'t exist!');
    }
    final String eventName = callback[0] as String;

    // Get the listeners.
    List<int>? listeners = _eventListeners[eventName];
    if (listeners == null) {
      throw ArgumentError('Event listeners don\'t exist for $eventName!');
    }

    // Update both maps.
    _eventCallbacks.remove(listener);

    listeners = listeners.where((l) => l != listener).toList();
    _eventListeners[eventName] = listeners;
    if (listeners.isEmpty) {
      _eventListeners.remove(eventName);
    }

    // Kill subscription if all listeners have been removed.
    if (_eventCallbacks.isEmpty) {
      if (_eventListeners.isNotEmpty) {
        throw StateError(
          'Expected event listeners size to be 0 but got ${_eventListeners.length}',
        );
      }

      await _disposePrimarySubscription();
    }
  }

  /// Subscribe to program account changes using espresso-cash patterns
  ///
  /// Provides program-level account monitoring with filtering capabilities.
  Stream<dto.Account> subscribeProgramAccounts({
    List<dto.ProgramFilter>? filters,
    Commitment? commitment,
    dto.Encoding encoding = dto.Encoding.jsonParsed,
  }) {
    final subscriptionClient = _provider.connection.createSubscriptionClient();

    return subscriptionClient
        .programSubscribe(
          _programId.toBase58(),
          encoding: encoding,
          filters: filters,
          commitment: _convertCommitmentToSolana(commitment) ??
              dto.Commitment.confirmed,
        )
        .cast<dto.Account>();
  }

  /// Subscribe to specific account changes using espresso-cash patterns
  ///
  /// Monitors individual account updates with espresso-cash reliability.
  Stream<dto.Account> subscribeAccount(
    PublicKey accountAddress, {
    Commitment? commitment,
    dto.Encoding encoding = dto.Encoding.jsonParsed,
  }) {
    final subscriptionClient = _provider.connection.createSubscriptionClient();

    return subscriptionClient.accountSubscribe(
      accountAddress.toBase58(),
      commitment:
          _convertCommitmentToSolana(commitment) ?? dto.Commitment.confirmed,
      encoding: encoding,
    );
  }

  /// Get comprehensive subscription statistics
  EventStats get stats => EventStats(
        totalEvents: _totalEvents,
        parsedEvents: _totalEvents - _parseErrors,
        parseErrors: _parseErrors,
        filteredEvents: _filterMatches,
        lastProcessed: _lastEvent ?? DateTime.now(),
        eventsPerSecond: _calculateEventsPerSecond(),
      );

  /// Get current subscription state
  WebSocketState get state => _primarySubscription != null
      ? WebSocketState.connected
      : WebSocketState.disconnected;

  /// State change stream for monitoring
  Stream<WebSocketState> get stateStream => Stream.value(state);

  /// Ensure primary logs subscription exists (internal)
  void _ensurePrimarySubscription(Commitment? commitment) {
    if (_primarySubscription != null) return;

    // Use Future.microtask for async setup while keeping addEventListener sync
    Future.microtask(() async {
      if (_primarySubscription != null) return;

      try {
        final subscriptionClient =
            _provider.connection.createSubscriptionClient();
        final filter = LogsFilter.mentions([_programId.toBase58()]);
        final solanaCommitment = _convertCommitmentToSolana(commitment);

        _primarySubscription = subscriptionClient
            .logsSubscribe(
          filter,
          commitment: solanaCommitment ?? dto.Commitment.confirmed,
        )
            .listen(
          (dto.Logs logsData) {
            _processLogsData(logsData);
          },
          onError: (error) {
            _parseErrors++;
            // Log error but maintain subscription
          },
          onDone: () {
            _primarySubscription = null;
          },
        );
      } catch (e) {
        _primarySubscription = null;
        _parseErrors++;
      }
    });
  }

  /// Process logs data from espresso-cash subscription
  void _processLogsData(dto.Logs logsData) {
    if (logsData.err != null) {
      return; // Skip failed transactions
    }

    try {
      _totalEvents++;
      _lastEvent = DateTime.now();

      final events = _eventParser.parseLogs(logsData.logs);

      for (final event in events) {
        final allListeners = _eventListeners[event.name];

        if (allListeners != null) {
          _filterMatches++;

          for (final listener in allListeners) {
            final listenerCb = _eventCallbacks[listener];

            if (listenerCb != null) {
              final callback = listenerCb[1] as EventCallback;
              // Call with TypeScript-compatible signature
              callback(event.data, 0, logsData.signature);
            }
          }
        }
      }
    } catch (e) {
      _parseErrors++;
      // Continue processing other events
    }
  }

  /// Calculate events per second for statistics
  double _calculateEventsPerSecond() {
    final lastEvent = _lastEvent;
    if (lastEvent == null || _totalEvents == 0) return 0.0;

    final elapsed = DateTime.now().difference(lastEvent);
    if (elapsed.inSeconds == 0) return 0.0;

    return _totalEvents / elapsed.inSeconds;
  }

  /// Convert dart-coral-xyz Commitment to espresso-cash Commitment
  dto.Commitment? _convertCommitmentToSolana(Commitment? commitment) {
    if (commitment == null) return null;

    switch (commitment) {
      case Commitment.processed:
        return dto.Commitment.processed;
      case Commitment.confirmed:
        return dto.Commitment.confirmed;
      case Commitment.finalized:
        return dto.Commitment.finalized;
      case Commitment.max:
      case Commitment.root:
      case Commitment.single:
      default:
        return dto.Commitment.finalized; // Safe default
    }
  }

  /// Dispose primary subscription (internal)
  Future<void> _disposePrimarySubscription() async {
    if (_primarySubscription != null) {
      await _primarySubscription!.cancel();
      _primarySubscription = null;
    }
  }

  /// Advanced event filtering with custom criteria
  ///
  /// Provides complex event filtering beyond basic event name matching.
  Stream<ParsedEvent> createFilteredEventStream({
    Set<String>? eventNames,
    bool Function(ParsedEvent)? customFilter,
    Commitment? commitment,
  }) {
    final controller = StreamController<ParsedEvent>.broadcast();

    // Internal listener to capture all events
    int? listenerId;

    // Listen to all events if no specific names provided
    final targetEvents = eventNames ?? _eventListeners.keys.toSet();

    for (final eventName in targetEvents) {
      listenerId = addEventListener<dynamic>(
        eventName,
        (event, slot, signature) {
          final parsedEvent = ParsedEvent(
            name: eventName,
            data: event,
            slot: slot,
            signature: signature,
          );

          // Apply custom filter if provided
          if (customFilter == null || customFilter(parsedEvent)) {
            controller.add(parsedEvent);
          }
        },
        commitment: commitment,
      );
    }

    // Handle stream cancellation
    controller.onCancel = () {
      if (listenerId != null) {
        removeEventListener(listenerId);
      }
    };

    return controller.stream;
  }

  /// Get active listener information for debugging
  Map<String, dynamic> getListenerInfo() {
    return {
      'totalListeners': _eventCallbacks.length,
      'eventTypes': _eventListeners.keys.toList(),
      'listenersByEvent': Map.fromEntries(
        _eventListeners.entries.map(
          (e) => MapEntry(e.key, e.value.length),
        ),
      ),
      'subscriptionActive': _primarySubscription != null,
      'statistics': stats.toMap(),
    };
  }

  /// Dispose all subscriptions and clean up resources
  Future<void> dispose() async {
    // Remove all listeners
    final listenerIds = List<int>.from(_eventCallbacks.keys);
    for (final id in listenerIds) {
      await removeEventListener(id);
    }

    // Clean up any remaining subscriptions
    await _disposePrimarySubscription();

    for (final subscription in _subscriptions.values) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }
}

/// Event callback type matching TypeScript SDK exactly
typedef EventCallback<T> = void Function(T event, int slot, String signature);

/// Parsed event data structure
class ParsedEvent {
  /// Creates a parsed event instance
  ParsedEvent({
    required this.name,
    required this.data,
    required this.slot,
    required this.signature,
  });

  /// Event name
  final String name;

  /// Event data payload
  final dynamic data;

  /// Slot number when event occurred
  final int slot;

  /// Transaction signature
  final String signature;
}

/// Extension for EventStats to include toMap for debugging
extension EventStatsExtension on EventStats {
  Map<String, dynamic> toMap() {
    return {
      'totalEvents': totalEvents,
      'parsedEvents': parsedEvents,
      'parseErrors': parseErrors,
      'filteredEvents': filteredEvents,
      'lastProcessed': lastProcessed.toIso8601String(),
      'eventsPerSecond': eventsPerSecond,
    };
  }
}
