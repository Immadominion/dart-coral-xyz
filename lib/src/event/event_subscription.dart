/// Event subscription interfaces and implementations
///
/// This module provides the core interfaces for event subscriptions,
/// allowing clients to manage event listeners and their lifecycle.
library;

import 'dart:async';
import 'package:coral_xyz_anchor/src/event/types.dart';

/// Interface for event subscriptions
///
/// Represents an active event subscription that can be cancelled
/// and provides access to subscription metadata and statistics.
abstract class EventSubscription {
  /// Unique subscription ID
  String get id;

  /// Whether the subscription is currently active
  bool get isActive;

  /// Event filter for this subscription (if any)
  EventFilter? get filter;

  /// Cancel the subscription and stop receiving events
  Future<void> cancel();

  /// Get subscription statistics
  EventStats get stats;
}

/// Basic implementation of EventSubscription
class BasicEventSubscription implements EventSubscription {

  BasicEventSubscription({
    required this.id,
    required Future<void> Function() cancelFunction,
    required EventStats Function() statsFunction,
    this.filter,
  })  : _cancelFunction = cancelFunction,
        _statsFunction = statsFunction;
  @override
  final String id;

  final Future<void> Function() _cancelFunction;
  final EventStats Function() _statsFunction;

  @override
  final EventFilter? filter;

  bool _isActive = true;

  @override
  bool get isActive => _isActive;

  @override
  Future<void> cancel() async {
    if (_isActive) {
      _isActive = false;
      await _cancelFunction();
    }
  }

  @override
  EventStats get stats => _statsFunction();
}

/// Subscription handle that manages multiple child subscriptions
class CompositeEventSubscription implements EventSubscription {

  CompositeEventSubscription({
    required this.id,
    this.filter,
  });
  @override
  final String id;

  @override
  final EventFilter? filter;

  final List<EventSubscription> _childSubscriptions = [];
  bool _isActive = true;

  /// Add a child subscription
  void addChild(EventSubscription subscription) {
    if (_isActive) {
      _childSubscriptions.add(subscription);
    }
  }

  /// Remove a child subscription
  void removeChild(EventSubscription subscription) {
    _childSubscriptions.remove(subscription);
  }

  @override
  bool get isActive => _isActive && _childSubscriptions.any((s) => s.isActive);

  @override
  Future<void> cancel() async {
    if (_isActive) {
      _isActive = false;

      // Cancel all child subscriptions
      await Future.wait(_childSubscriptions.map((s) => s.cancel()));
      _childSubscriptions.clear();
    }
  }

  @override
  EventStats get stats {
    if (_childSubscriptions.isEmpty) {
      return EventStats(
        totalEvents: 0,
        parsedEvents: 0,
        parseErrors: 0,
        filteredEvents: 0,
        lastProcessed: DateTime.now(),
        eventsPerSecond: 0,
      );
    }

    // Aggregate stats from all child subscriptions
    var totalEvents = 0;
    var parsedEvents = 0;
    var parseErrors = 0;
    var filteredEvents = 0;
    DateTime lastProcessed = DateTime.now();
    var eventsPerSecond = 0.0;

    for (final child in _childSubscriptions) {
      final childStats = child.stats;
      totalEvents += childStats.totalEvents;
      parsedEvents += childStats.parsedEvents;
      parseErrors += childStats.parseErrors;
      filteredEvents += childStats.filteredEvents;
      eventsPerSecond += childStats.eventsPerSecond;

      if (childStats.lastProcessed.isAfter(lastProcessed)) {
        lastProcessed = childStats.lastProcessed;
      }
    }

    return EventStats(
      totalEvents: totalEvents,
      parsedEvents: parsedEvents,
      parseErrors: parseErrors,
      filteredEvents: filteredEvents,
      lastProcessed: lastProcessed,
      eventsPerSecond: eventsPerSecond,
    );
  }
}

/// Event subscription builder for fluent API
class EventSubscriptionBuilder {
  EventFilter? _filter;
  String? _id;

  /// Set the event filter
  EventSubscriptionBuilder filter(EventFilter filter) {
    _filter = filter;
    return this;
  }

  /// Set the subscription ID
  EventSubscriptionBuilder id(String id) {
    _id = id;
    return this;
  }

  /// Filter by event names
  EventSubscriptionBuilder events(Set<String> eventNames) {
    _filter = EventFilter.byEventNames(eventNames);
    return this;
  }

  /// Filter by single event name
  EventSubscriptionBuilder event(String eventName) => events({eventName});

  /// Filter by slot range
  EventSubscriptionBuilder slotRange(int minSlot, [int? maxSlot]) {
    _filter = EventFilter.bySlotRange(minSlot, maxSlot);
    return this;
  }

  /// Create the subscription with the configured parameters
  BasicEventSubscription build({
    required Future<void> Function() cancelFunction,
    required EventStats Function() statsFunction,
  }) => BasicEventSubscription(
      id: _id ?? 'subscription_${DateTime.now().millisecondsSinceEpoch}',
      cancelFunction: cancelFunction,
      statsFunction: statsFunction,
      filter: _filter,
    );
}
