/// Advanced event filtering utilities
///
/// This module provides sophisticated event filtering capabilities
/// including composite filters, conditional logic, and performance
/// optimizations for high-throughput event processing.
library;

import 'package:coral_xyz_anchor/src/types/public_key.dart';
import 'package:coral_xyz_anchor/src/event/types.dart';

/// Advanced event filter with complex logic
class AdvancedEventFilter {

  AdvancedEventFilter({FilterOperator operator = FilterOperator.and})
      : _operator = operator;
  final List<FilterCriteria> _criteria = [];
  final FilterOperator _operator;

  /// Add a filter criteria
  AdvancedEventFilter where(FilterCriteria criteria) {
    _criteria.add(criteria);
    return this;
  }

  /// Add an event name filter
  AdvancedEventFilter eventName(String name) => where(EventNameCriteria(name));

  /// Add an event names filter (any of the specified names)
  AdvancedEventFilter eventNames(Set<String> names) => where(EventNamesCriteria(names));

  /// Add a program ID filter
  AdvancedEventFilter programId(PublicKey programId) => where(ProgramIdCriteria(programId));

  /// Add a slot range filter
  AdvancedEventFilter slotRange(int minSlot, [int? maxSlot]) => where(SlotRangeCriteria(minSlot, maxSlot));

  /// Add a data field filter
  AdvancedEventFilter dataField(String fieldName, dynamic value) => where(DataFieldCriteria(fieldName, value));

  /// Add a custom filter function
  AdvancedEventFilter custom(bool Function(ParsedEvent, PublicKey) filter) => where(CustomCriteria(filter));

  /// Check if an event matches the filter
  bool matches(ParsedEvent event, PublicKey programId) {
    if (_criteria.isEmpty) return true;

    switch (_operator) {
      case FilterOperator.and:
        return _criteria
            .every((criteria) => criteria.matches(event, programId));
      case FilterOperator.or:
        return _criteria.any((criteria) => criteria.matches(event, programId));
      case FilterOperator.not:
        return _criteria.isEmpty || !_criteria.first.matches(event, programId);
    }
  }

  /// Get a summary of the filter criteria
  String get summary {
    if (_criteria.isEmpty) return 'No filters';

    final descriptions = _criteria
        .map((c) => c.description)
        .join(' ${_operator.name.toUpperCase()} ');
    return descriptions;
  }
}

/// Filter operator for combining criteria
enum FilterOperator {
  and,
  or,
  not,
}

/// Base class for filter criteria
abstract class FilterCriteria {
  /// Check if the criteria matches the event
  bool matches(ParsedEvent event, PublicKey programId);

  /// Human-readable description of the criteria
  String get description;
}

/// Filter by event name
class EventNameCriteria extends FilterCriteria {

  EventNameCriteria(this.eventName);
  final String eventName;

  @override
  bool matches(ParsedEvent event, PublicKey programId) => event.name == eventName;

  @override
  String get description => 'event name = $eventName';
}

/// Filter by multiple event names (OR logic)
class EventNamesCriteria extends FilterCriteria {

  EventNamesCriteria(this.eventNames);
  final Set<String> eventNames;

  @override
  bool matches(ParsedEvent event, PublicKey programId) => eventNames.contains(event.name);

  @override
  String get description => 'event name in {${eventNames.join(', ')}}';
}

/// Filter by program ID
class ProgramIdCriteria extends FilterCriteria {

  ProgramIdCriteria(this.programId);
  final PublicKey programId;

  @override
  bool matches(ParsedEvent event, PublicKey eventProgramId) => eventProgramId == programId;

  @override
  String get description => 'program ID = ${programId.toBase58()}';
}

/// Filter by slot range
class SlotRangeCriteria extends FilterCriteria {

  SlotRangeCriteria(this.minSlot, [this.maxSlot]);
  final int minSlot;
  final int? maxSlot;

  @override
  bool matches(ParsedEvent event, PublicKey programId) {
    final slot = event.context.slot;
    if (slot < minSlot) return false;
    if (maxSlot != null && slot > maxSlot!) return false;
    return true;
  }

  @override
  String get description {
    if (maxSlot != null) {
      return 'slot in [$minSlot, $maxSlot]';
    } else {
      return 'slot >= $minSlot';
    }
  }
}

/// Filter by data field value
class DataFieldCriteria extends FilterCriteria {

  DataFieldCriteria(this.fieldName, this.expectedValue);
  final String fieldName;
  final dynamic expectedValue;

  @override
  bool matches(ParsedEvent event, PublicKey programId) {
    try {
      final data = event.data;
      if (data is Map<String, dynamic>) {
        return data[fieldName] == expectedValue;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  @override
  String get description => '$fieldName = $expectedValue';
}

/// Custom filter function
class CustomCriteria extends FilterCriteria {

  CustomCriteria(this._filter, {String description = 'custom filter'})
      : _description = description;
  final bool Function(ParsedEvent, PublicKey) _filter;
  final String _description;

  @override
  bool matches(ParsedEvent event, PublicKey programId) {
    try {
      return _filter(event, programId);
    } catch (e) {
      return false;
    }
  }

  @override
  String get description => _description;
}

/// Composite filter that combines multiple filters
class CompositeEventFilter {

  CompositeEventFilter({FilterOperator operator = FilterOperator.and})
      : _operator = operator;
  final List<AdvancedEventFilter> _filters = [];
  final FilterOperator _operator;

  /// Add a sub-filter
  CompositeEventFilter add(AdvancedEventFilter filter) {
    _filters.add(filter);
    return this;
  }

  /// Create and add a new sub-filter
  CompositeEventFilter addFilter(
      AdvancedEventFilter Function(AdvancedEventFilter) builder,) {
    final filter = builder(AdvancedEventFilter());
    return add(filter);
  }

  /// Check if an event matches the composite filter
  bool matches(ParsedEvent event, PublicKey programId) {
    if (_filters.isEmpty) return true;

    switch (_operator) {
      case FilterOperator.and:
        return _filters.every((filter) => filter.matches(event, programId));
      case FilterOperator.or:
        return _filters.any((filter) => filter.matches(event, programId));
      case FilterOperator.not:
        return _filters.isEmpty || !_filters.first.matches(event, programId);
    }
  }

  /// Get the number of sub-filters
  int get filterCount => _filters.length;

  /// Get a summary of all filters
  String get summary {
    if (_filters.isEmpty) return 'No filters';

    final summaries = _filters
        .map((f) => '(${f.summary})')
        .join(' ${_operator.name.toUpperCase()} ');
    return summaries;
  }
}

/// Pre-built filter patterns for common use cases
class FilterPatterns {
  /// Filter for specific event types with optional data constraints
  static AdvancedEventFilter eventOfType(String eventName,
      {Map<String, dynamic>? dataConstraints,}) {
    final filter = AdvancedEventFilter().eventName(eventName);

    if (dataConstraints != null) {
      for (final entry in dataConstraints.entries) {
        filter.dataField(entry.key, entry.value);
      }
    }

    return filter;
  }

  /// Filter for events in a time range (using slot numbers as proxy)
  static AdvancedEventFilter timeRange(int fromSlot, int toSlot) => AdvancedEventFilter().slotRange(fromSlot, toSlot);

  /// Filter for events from multiple programs
  static CompositeEventFilter multiplePrograms(Set<PublicKey> programIds) {
    final composite = CompositeEventFilter(operator: FilterOperator.or);
    for (final programId in programIds) {
      composite.add(AdvancedEventFilter().programId(programId));
    }
    return composite;
  }

  /// Filter for high-value events (custom logic based on data)
  static AdvancedEventFilter highValue(double threshold) => AdvancedEventFilter().custom(
      (event, programId) {
        try {
          final data = event.data as Map<String, dynamic>?;
          if (data == null) return false;

          // Look for common value fields
          for (final field in ['amount', 'value', 'lamports', 'tokens']) {
            if (data.containsKey(field)) {
              final value = data[field];
              if (value is num && value.toDouble() >= threshold) {
                return true;
              }
            }
          }
          return false;
        } catch (e) {
          return false;
        }
      },
    );

  /// Filter for recent events (within last N slots)
  static AdvancedEventFilter recent(int currentSlot, int lookbackSlots) => AdvancedEventFilter().slotRange(currentSlot - lookbackSlots);

  /// Filter for events with specific account involvement
  static AdvancedEventFilter involvingAccount(PublicKey account) => AdvancedEventFilter().custom(
      (event, programId) {
        try {
          final data = event.data as Map<String, dynamic>?;
          if (data == null) return false;

          final accountStr = account.toBase58();

          // Check all string values in the data for the account
          for (final value in data.values) {
            if (value is String && value == accountStr) {
              return true;
            }
          }
          return false;
        } catch (e) {
          return false;
        }
      },
    );
}

/// Filter performance metrics
class FilterMetrics {
  int _totalEvents = 0;
  int _matchedEvents = 0;
  int _filteredEvents = 0;
  DateTime? _lastReset;
  final List<Duration> _processingTimes = [];

  /// Record a filter operation
  void recordFilter(bool matched, Duration processingTime) {
    _totalEvents++;
    if (matched) {
      _matchedEvents++;
    } else {
      _filteredEvents++;
    }

    _processingTimes.add(processingTime);

    // Keep only recent measurements
    while (_processingTimes.length > 1000) {
      _processingTimes.removeAt(0);
    }
  }

  /// Reset metrics
  void reset() {
    _totalEvents = 0;
    _matchedEvents = 0;
    _filteredEvents = 0;
    _lastReset = DateTime.now();
    _processingTimes.clear();
  }

  /// Total events processed
  int get totalEvents => _totalEvents;

  /// Events that matched the filter
  int get matchedEvents => _matchedEvents;

  /// Events that were filtered out
  int get filteredEvents => _filteredEvents;

  /// Filter match rate (0.0 to 1.0)
  double get matchRate =>
      _totalEvents > 0 ? _matchedEvents / _totalEvents : 0.0;

  /// Average processing time per event
  Duration get averageProcessingTime {
    if (_processingTimes.isEmpty) return Duration.zero;

    final totalMicroseconds =
        _processingTimes.map((d) => d.inMicroseconds).reduce((a, b) => a + b);

    return Duration(microseconds: totalMicroseconds ~/ _processingTimes.length);
  }

  /// Maximum processing time recorded
  Duration get maxProcessingTime {
    if (_processingTimes.isEmpty) return Duration.zero;
    return _processingTimes.reduce((a, b) => a > b ? a : b);
  }

  /// When metrics were last reset
  DateTime? get lastReset => _lastReset;
}
