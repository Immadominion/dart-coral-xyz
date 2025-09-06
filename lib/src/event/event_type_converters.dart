/// Event type conversion utilities for maintaining consistency between
/// Event<IdlEvent> and ParsedEvent<dynamic> across the system
library;

import 'dart:async';

import 'package:coral_xyz/src/event/types.dart';
import 'package:coral_xyz/src/idl/idl.dart';
import 'package:coral_xyz/src/coder/event_coder.dart' show Event;
import 'package:coral_xyz/src/types/public_key.dart';

/// Utilities for converting between different event type representations
class EventTypeConverters {
  /// Convert Event<IdlEvent, dynamic> to ParsedEvent<dynamic> with context
  static ParsedEvent<dynamic> eventToParsedEvent(
    Event<IdlEvent, dynamic> event, {
    EventContext? context,
    IdlEvent? eventDef,
  }) {
    return ParsedEvent<dynamic>(
      name: event.name,
      data: event.data,
      context: context ?? _createDefaultContext(),
      eventDef: eventDef ?? _createDefaultEventDef(event.name),
    );
  }

  /// Convert ParsedEvent<T> to Event<IdlEvent>
  static Event<IdlEvent, T> parsedEventToEvent<T>(ParsedEvent<T> parsedEvent) {
    return Event<IdlEvent, T>(
      name: parsedEvent.name,
      data: parsedEvent.data,
      eventDef: parsedEvent.eventDef,
      programId: PublicKey.fromBase58(
          '11111111111111111111111111111111'), // Placeholder
    );
  }

  /// Convert ParsedEvent<T> to ParsedEvent<dynamic> for compatibility
  static ParsedEvent<dynamic> parsedEventToDynamic<T>(
      ParsedEvent<T> parsedEvent) {
    return ParsedEvent<dynamic>(
      name: parsedEvent.name,
      data: parsedEvent.data,
      context: parsedEvent.context,
      eventDef: parsedEvent.eventDef,
    );
  }

  /// Convert ParsedEvent<dynamic> to ParsedEvent<T> with type assertion
  static ParsedEvent<T> parsedEventToTyped<T>(
      ParsedEvent<dynamic> parsedEvent) {
    return ParsedEvent<T>(
      name: parsedEvent.name,
      data: parsedEvent.data as T,
      context: parsedEvent.context,
      eventDef: parsedEvent.eventDef,
    );
  }

  /// Normalize a list of mixed event types to ParsedEvent<dynamic>
  static List<ParsedEvent<dynamic>> normalizeEventList(List<dynamic> events) {
    final result = <ParsedEvent<dynamic>>[];

    for (final event in events) {
      if (event is ParsedEvent<dynamic>) {
        result.add(event);
      } else if (event is ParsedEvent) {
        result.add(parsedEventToDynamic(event));
      } else if (event is Event<IdlEvent, dynamic>) {
        result.add(eventToParsedEvent(event));
      } else {
        throw ArgumentError.value(
            event, 'event', 'Must be Event<IdlEvent> or ParsedEvent<T>');
      }
    }

    return result;
  }

  /// Convert a stream of mixed event types to ParsedEvent<dynamic>
  static Stream<ParsedEvent<dynamic>> normalizeEventStream(
      Stream<dynamic> events) {
    return events.map((event) {
      if (event is ParsedEvent<dynamic>) {
        return event;
      } else if (event is ParsedEvent) {
        return parsedEventToDynamic(event);
      } else if (event is Event<IdlEvent, dynamic>) {
        return eventToParsedEvent(event);
      } else {
        throw ArgumentError.value(
            event, 'event', 'Must be Event<IdlEvent> or ParsedEvent<T>');
      }
    });
  }

  /// Batch convert events preserving type information where possible
  static List<ParsedEvent<T>> convertEventBatch<T>(
    List<dynamic> events,
    T Function(dynamic) dataConverter,
  ) {
    final result = <ParsedEvent<T>>[];

    for (final event in events) {
      if (event is ParsedEvent) {
        result.add(ParsedEvent<T>(
          name: event.name,
          data: dataConverter(event.data),
          context: event.context,
          eventDef: event.eventDef,
        ));
      } else if (event is Event<IdlEvent, dynamic>) {
        result.add(ParsedEvent<T>(
          name: event.name,
          data: dataConverter(event.data),
          context: _createDefaultContext(),
          eventDef: _createDefaultEventDef(event.name),
        ));
      } else {
        throw ArgumentError.value(
            event, 'event', 'Must be Event<IdlEvent> or ParsedEvent<T>');
      }
    }

    return result;
  }

  /// Ensure type consistency for event handlers that expect specific types
  static void validateEventType<T>(ParsedEvent<T> event, Type expectedType) {
    if (event.data.runtimeType != expectedType) {
      throw StateError(
          'Event data type mismatch: expected $expectedType, got ${event.data.runtimeType}');
    }
  }

  /// Create a merger for combining events from different sources
  static Stream<ParsedEvent<dynamic>> mergeEventStreams(
    List<Stream<dynamic>> streams,
  ) {
    // Convert all streams to normalized format
    final normalizedStreams = streams.map(normalizeEventStream).toList();

    // Merge all streams using StreamGroup
    final controller = StreamController<ParsedEvent<dynamic>>();

    for (final stream in normalizedStreams) {
      stream.listen(
        (event) => controller.add(event),
        onError: (Object error) => controller.addError(error),
        onDone: () {
          // Close controller only when all streams are done
          // This is simplified - a full implementation would track all streams
        },
      );
    }

    return controller.stream;
  }

  /// Helper to create default context when missing
  static EventContext _createDefaultContext() {
    return const EventContext(
      slot: 0,
      signature: '',
      blockTime: null,
      metadata: null,
    );
  }

  /// Helper to create default event definition when missing
  static IdlEvent _createDefaultEventDef(String name) {
    return IdlEvent(
      name: name,
      fields: [],
    );
  }

  /// Type-safe event filtering
  static Stream<ParsedEvent<T>> filterEventType<T>(
    Stream<ParsedEvent<dynamic>> events,
    String eventName,
    T Function(dynamic) dataConverter,
  ) {
    return events
        .where((event) => event.name == eventName)
        .map((event) => ParsedEvent<T>(
              name: event.name,
              data: dataConverter(event.data),
              context: event.context,
              eventDef: event.eventDef,
            ));
  }

  /// Create type-safe event handlers that can accept either Event or ParsedEvent
  static void Function(ParsedEvent<dynamic>) wrapEventHandler<T>(
    void Function(T) handler,
    T Function(dynamic) dataConverter,
  ) {
    return (ParsedEvent<dynamic> event) {
      try {
        final data = dataConverter(event.data);
        handler(data);
      } catch (e) {
        throw StateError('Failed to convert event data for handler: $e');
      }
    };
  }

  /// Debug helper to inspect event type information
  static Map<String, dynamic> inspectEvent(dynamic event) {
    if (event is ParsedEvent) {
      return {
        'type': 'ParsedEvent',
        'genericType': event.data.runtimeType.toString(),
        'name': event.name,
        'hasContext': true,
        'contextSlot': event.context.slot,
        'eventDefName': event.eventDef.name,
      };
    } else if (event is Event<IdlEvent, dynamic>) {
      return {
        'type': 'Event',
        'name': event.name,
        'dataType': event.data.runtimeType.toString(),
        'hasContext': false,
      };
    } else {
      return {
        'type': 'Unknown',
        'runtimeType': event.runtimeType.toString(),
      };
    }
  }
}
