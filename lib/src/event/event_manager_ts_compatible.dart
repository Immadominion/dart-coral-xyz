/// Event management system matching TypeScript Anchor's EventManager exactly
///
/// This implementation provides 100% API compatibility with TypeScript Anchor's
/// EventManager, including:
/// - Synchronous addEventListener returning numeric listener ID
/// - Async removeEventListener taking numeric ID
/// - Automatic subscription management
/// - Event parsing and distribution

import 'dart:async';
import '../types/public_key.dart';
import '../types/commitment.dart';
import '../provider/anchor_provider.dart';
import '../coder/main_coder.dart';
import 'types.dart';
import 'event_parser.dart';

/// TypeScript-compatible event callback type
typedef EventCallback<T> = void Function(T event, int slot, String signature);

/// Logs notification data structure
class LogsNotification {
  final String signature;
  final List<String> logs;
  final String? err;
  final int slot;
  final DateTime? blockTime;

  LogsNotification({
    required this.signature,
    required this.logs,
    this.err,
    required this.slot,
    this.blockTime,
  });

  bool get isSuccess => err == null;
}

/// Event management system matching TypeScript Anchor's EventManager exactly
class EventManager {
  /// Program ID for event subscriptions.
  final PublicKey _programId;

  /// Network and wallet provider.
  final AnchorProvider _provider;

  /// Event parser to handle onLogs callbacks.
  final EventParser _eventParser;

  /// Maps event listener id to [event-name, callback].
  final Map<int, List<dynamic>> _eventCallbacks = <int, List<dynamic>>{};

  /// Maps event name to all listeners for the event.
  final Map<String, List<int>> _eventListeners = <String, List<int>>{};

  /// The next listener id to allocate.
  int _listenerIdCount = 0;

  /// The subscription id from the connection onLogs subscription.
  String? _onLogsSubscriptionId;

  /// Simple statistics tracking
  int _totalEvents = 0;
  int _parseErrors = 0;

  EventManager(PublicKey programId, AnchorProvider provider, BorshCoder coder)
      : _programId = programId,
        _provider = provider,
        _eventParser = EventParser(programId: programId, coder: coder);

  /// Add event listener - matches TypeScript API exactly
  ///
  /// Returns numeric listener ID synchronously like TypeScript.
  /// The subscription setup happens asynchronously but doesn't block.
  int addEventListener<T>(
    String eventName,
    EventCallback<T> callback, {
    CommitmentConfig? commitment,
  }) {
    int listener = _listenerIdCount;
    _listenerIdCount += 1;

    // Store the listener into the event map.
    if (!_eventListeners.containsKey(eventName)) {
      _eventListeners[eventName] = <int>[];
    }
    _eventListeners[eventName] = (_eventListeners[eventName] ?? <int>[])
      ..add(listener);

    // Store the callback into the listener map.
    _eventCallbacks[listener] = [eventName, callback];

    // Create the subscription singleton, if needed.
    if (_onLogsSubscriptionId != null) {
      return listener;
    }

    // Start logs subscription asynchronously (don't await to keep method sync)
    _startLogsSubscription(commitment);

    return listener;
  }

  /// Remove event listener - matches TypeScript API exactly
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

    // Kill the websocket connection if all listeners have been removed.
    if (_eventCallbacks.isEmpty) {
      if (_eventListeners.isNotEmpty) {
        throw StateError(
            'Expected event listeners size to be 0 but got ${_eventListeners.length}');
      }

      if (_onLogsSubscriptionId != null) {
        await _provider.connection.removeOnLogsListener(_onLogsSubscriptionId!);
        _onLogsSubscriptionId = null;
      }
    }
  }

  /// Start logs subscription (internal method)
  void _startLogsSubscription(CommitmentConfig? commitment) {
    // Use Future.microtask to make this async while keeping addEventListener sync
    Future.microtask(() async {
      if (_onLogsSubscriptionId != null) return;

      try {
        _onLogsSubscriptionId = await _provider.connection.onLogs(
          _programId,
          (logs) {
            if (logs.err != null) {
              return;
            }

            try {
              _totalEvents++;
              final events = _eventParser.parseLogs(logs.logs);

              for (final event in events) {
                final allListeners = _eventListeners[event.name];

                if (allListeners != null) {
                  for (final listener in allListeners) {
                    final listenerCb = _eventCallbacks[listener];

                    if (listenerCb != null) {
                      final callback = listenerCb[1] as EventCallback;
                      // Call the callback with event data, slot, and signature
                      callback(event.data, logs.slot, logs.signature);
                    }
                  }
                }
              }
            } catch (e) {
              _parseErrors++;
              // Log error but don't break subscription
            }
          },
          commitment: commitment,
        );
      } catch (e) {
        // Handle subscription error
        _onLogsSubscriptionId = null;
      }
    });
  }

  /// Get basic event statistics
  EventStats get stats => EventStats(
        totalEvents: _totalEvents,
        parsedEvents: _totalEvents - _parseErrors,
        parseErrors: _parseErrors,
        filteredEvents: 0, // Simplified for now
        lastProcessed: DateTime.now(),
        eventsPerSecond: 0.0, // Simplified for now
      );

  /// Simple connection state
  WebSocketState get state => _onLogsSubscriptionId != null
      ? WebSocketState.connected
      : WebSocketState.disconnected;

  /// Simple state stream
  Stream<WebSocketState> get stateStream => Stream.value(state);

  /// Dispose of all subscriptions
  Future<void> dispose() async {
    final subscriptionIds = List<int>.from(_eventCallbacks.keys);
    for (final id in subscriptionIds) {
      await removeEventListener(id);
    }
  }
}
