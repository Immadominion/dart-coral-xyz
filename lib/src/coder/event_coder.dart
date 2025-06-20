/// Event coder implementation for Anchor programs
///
/// This module provides the EventCoder interface and implementations
/// for parsing and decoding program events from transaction logs.

import '../idl/idl.dart';
import '../coder/borsh_types.dart';
import '../types/common.dart';
import 'dart:typed_data';
import 'dart:convert';

/// Interface for parsing and decoding program events
abstract class EventCoder {
  /// Decode an event from a log string
  ///
  /// [log] - The base64 encoded log string from a transaction
  /// Returns a decoded event or null if not recognized
  Event? decode<E extends IdlEvent>(String log);
}

/// Represents a decoded program event
class Event<E extends IdlEvent, T> {
  /// The event name
  final String name;

  /// The decoded event data
  final T data;

  /// The event definition from IDL
  final E eventDef;

  const Event({
    required this.name,
    required this.data,
    required this.eventDef,
  });

  @override
  String toString() {
    return 'Event(name: $name, data: $data)';
  }
}

/// Borsh-based implementation of EventCoder
class BorshEventCoder implements EventCoder {
  /// The IDL containing event definitions
  final Idl idl;

  /// Cached event layouts with discriminators
  late final Map<String, EventLayout> _eventLayouts;

  /// Create a new BorshEventCoder
  BorshEventCoder(this.idl) {
    _eventLayouts = _buildEventLayouts();
  }

  @override
  Event? decode<E extends IdlEvent>(String log) {
    Uint8List logData;

    try {
      // Decode base64 log string
      logData = base64.decode(log);
    } catch (e) {
      // Invalid base64 or empty log
      return null;
    }

    // Try to match against known event discriminators
    for (final entry in _eventLayouts.entries) {
      final eventName = entry.key;
      final layout = entry.value;

      if (logData.length < layout.discriminator.length) {
        continue;
      }

      // Check if discriminator matches
      bool matches = true;
      for (int i = 0; i < layout.discriminator.length; i++) {
        if (logData[i] != layout.discriminator[i]) {
          matches = false;
          break;
        }
      }

      if (matches) {
        try {
          // Skip discriminator and decode the event data
          final eventData = logData.sublist(layout.discriminator.length);
          final deserializer = BorshDeserializer(eventData);
          final decodedData = _decodeEventData(layout.typeDef, deserializer);

          return Event(
            name: eventName,
            data: decodedData,
            eventDef: layout.event as E,
          );
        } catch (e) {
          // Failed to decode, continue trying other events
          continue;
        }
      }
    }

    return null;
  }

  /// Build event layouts from IDL
  Map<String, EventLayout> _buildEventLayouts() {
    final layouts = <String, EventLayout>{};

    if (idl.events == null) {
      return layouts;
    }

    if (idl.types == null) {
      throw EventCoderException('Events require `idl.types`');
    }

    for (final event in idl.events!) {
      final typeDef = idl.types!.firstWhere(
        (ty) => ty.name == event.name,
        orElse: () =>
            throw EventCoderException('Event type not found: ${event.name}'),
      );

      layouts[event.name] = EventLayout(
        discriminator:
            event.discriminator ?? [], // Provide default empty list if null
        event: event,
        typeDef: typeDef,
      );
    }

    return layouts;
  }

  /// Decode event data based on its type definition
  dynamic _decodeEventData(IdlTypeDef typeDef, BorshDeserializer deserializer) {
    final typeSpec = typeDef.type;

    if (typeSpec.kind == 'struct') {
      final fields = typeSpec.fields;
      if (fields == null) {
        throw EventCoderException('Struct type missing fields');
      }

      final data = <String, dynamic>{};
      for (final field in fields) {
        data[field.name] = _decodeValue(field.type, deserializer);
      }
      return data;
    } else {
      throw EventCoderException('Unsupported event type: ${typeSpec.kind}');
    }
  }

  /// Decode a single value based on its IDL type
  dynamic _decodeValue(IdlType type, BorshDeserializer deserializer) {
    switch (type.kind) {
      case 'bool':
        return deserializer.readBool();
      case 'u8':
        return deserializer.readU8();
      case 'i8':
        return deserializer.readI8();
      case 'u16':
        return deserializer.readU16();
      case 'i16':
        return deserializer.readI16();
      case 'u32':
        return deserializer.readU32();
      case 'i32':
        return deserializer.readI32();
      case 'u64':
        return deserializer.readU64();
      case 'i64':
        return deserializer.readI64();
      case 'string':
        return deserializer.readString();
      case 'pubkey':
        return deserializer.readString();
      case 'vec':
        final length = deserializer.readU32();
        final list = <dynamic>[];
        for (int i = 0; i < length; i++) {
          list.add(_decodeValue(type.inner!, deserializer));
        }
        return list;
      case 'option':
        final hasValue = deserializer.readU8();
        if (hasValue == 0) {
          return null;
        } else {
          return _decodeValue(type.inner!, deserializer);
        }
      case 'array':
        final list = <dynamic>[];
        for (int i = 0; i < type.size!; i++) {
          list.add(_decodeValue(type.inner!, deserializer));
        }
        return list;
      case 'defined':
        // Handle user-defined types (nested structs)
        final typeName = type.defined;
        if (typeName == null) {
          throw EventCoderException('Defined type missing name');
        }
        final nestedTypeDef = idl.types?.firstWhere(
          (t) => t.name == typeName,
          orElse: () => throw EventCoderException('Type not found: $typeName'),
        );
        if (nestedTypeDef != null) {
          return _decodeEventData(nestedTypeDef, deserializer);
        }
        return null;
      default:
        throw EventCoderException(
            'Unsupported type for decoding: ${type.kind}');
    }
  }
}

/// Internal event layout information
class EventLayout {
  /// The event discriminator bytes
  final List<int> discriminator;

  /// The IDL event definition
  final IdlEvent event;

  /// The IDL type definition for this event
  final IdlTypeDef typeDef;

  const EventLayout({
    required this.discriminator,
    required this.event,
    required this.typeDef,
  });
}

/// Exception thrown by event coder operations
class EventCoderException extends AnchorException {
  const EventCoderException(String message, [dynamic cause])
      : super(message, cause);
}
