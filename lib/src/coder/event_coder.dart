/// Event coder implementation for Anchor programs
///
/// This module provides the EventCoder interface and implementations
/// for parsing and decoding program events from transaction logs.
library;

import 'package:coral_xyz/src/idl/idl.dart';
import 'package:coral_xyz/src/coder/borsh_types.dart';
import 'package:coral_xyz/src/types/common.dart';
import 'package:coral_xyz/src/types/public_key.dart';
import 'dart:typed_data';
import 'dart:convert';

/// Interface for parsing and decoding program events
abstract class EventCoder {
  /// Decode an event from a log string
  ///
  /// [log] - The base64 encoded log string from a transaction
  /// Returns a decoded event or null if not recognized
  Event<IdlEvent, dynamic>? decode<E extends IdlEvent>(String log);

  /// Encode an event to bytes
  ///
  /// [eventName] - The name of the event to encode
  /// [eventData] - The event data to encode
  /// Returns the encoded event bytes
  Uint8List encode(String eventName, dynamic eventData);
}

/// Represents a decoded program event
class Event<E extends IdlEvent, T> {
  const Event({
    required this.name,
    required this.data,
    required this.eventDef,
    required this.programId,
  });

  /// The event name
  final String name;

  /// The decoded event data
  final T data;

  /// The event definition from IDL
  final E eventDef;

  /// The program ID that emitted this event
  final PublicKey programId;

  @override
  String toString() => 'Event(name: $name, data: $data)';
}

/// Borsh-based implementation of EventCoder
class BorshEventCoder implements EventCoder {
  /// Create a new BorshEventCoder
  BorshEventCoder(this.idl, [this.programId]) {
    _eventLayouts = _buildEventLayouts();
  }

  /// The IDL containing event definitions
  final Idl idl;

  /// The program ID associated with events
  final PublicKey? programId;

  /// Cached event layouts with discriminators
  late final Map<String, EventLayout> _eventLayouts;

  /// Access to events encoding/decoding - exposes this instance
  EventCoder get events => this;

  @override
  Event<IdlEvent, dynamic>? decode<E extends IdlEvent>(String log) {
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

          return Event<IdlEvent, dynamic>(
            name: eventName,
            data: decodedData,
            eventDef: layout.event as E,
            programId: programId ?? PublicKeyUtils.defaultPubkey,
          );
        } catch (e) {
          // Failed to decode, continue trying other events
          continue;
        }
      }
    }

    return null;
  }

  @override
  Uint8List encode(String eventName, dynamic eventData) {
    final layout = _eventLayouts[eventName];
    if (layout == null) {
      throw EventCoderException('Unknown event: $eventName');
    }

    // Create discriminator + encoded data
    final discriminator = Uint8List.fromList(layout.discriminator);
    final encodedData = _encodeEventData(layout.typeDef, eventData);

    final totalLength = (discriminator.length + encodedData.length).round();
    final result = Uint8List(totalLength);
    result.setRange(0, discriminator.length, discriminator);
    result.setRange(discriminator.length, result.length, encodedData);

    return result;
  }

  /// Build event layouts from IDL
  Map<String, EventLayout> _buildEventLayouts() {
    final layouts = <String, EventLayout>{};

    if (idl.events == null) {
      return layouts;
    }

    if (idl.types == null) {
      throw const EventCoderException('Events require `idl.types`');
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
        throw const EventCoderException('Struct type missing fields');
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
          throw const EventCoderException('Defined type missing name');
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
          'Unsupported type for decoding: ${type.kind}',
        );
    }
  }

  /// Encode event data based on its type definition
  Uint8List _encodeEventData(IdlTypeDef typeDef, dynamic eventData) {
    final typeSpec = typeDef.type;

    if (typeSpec.kind == 'struct') {
      final fields = typeSpec.fields;
      if (fields == null) {
        throw const EventCoderException('Struct type missing fields');
      }

      final serializer = BorshSerializer();
      if (eventData is Map<String, dynamic>) {
        for (final field in fields) {
          final value = eventData[field.name];
          _encodeValue(field.type, value, serializer);
        }
      } else {
        throw const EventCoderException(
            'Event data must be a Map for struct type');
      }
      return serializer.toBytes();
    } else {
      throw EventCoderException(
          'Unsupported event type for encoding: ${typeSpec.kind}');
    }
  }

  /// Encode a single value based on its IDL type
  void _encodeValue(IdlType type, dynamic value, BorshSerializer serializer) {
    switch (type.kind) {
      case 'bool':
        serializer.writeBool(value as bool);
        break;
      case 'u8':
        serializer.writeU8(value as int);
        break;
      case 'i8':
        serializer.writeI8(value as int);
        break;
      case 'u16':
        serializer.writeU16(value as int);
        break;
      case 'i16':
        serializer.writeI16(value as int);
        break;
      case 'u32':
        serializer.writeU32(value as int);
        break;
      case 'i32':
        serializer.writeI32(value as int);
        break;
      case 'u64':
        serializer.writeU64(value is String ? int.parse(value) : value as int);
        break;
      case 'i64':
        serializer.writeI64(value is String ? int.parse(value) : value as int);
        break;
      case 'string':
        serializer.writeString(value as String);
        break;
      case 'pubkey':
        serializer.writeString(value as String);
        break;
      case 'vec':
        final list = value as List;
        serializer.writeU32(list.length);
        for (final item in list) {
          _encodeValue(type.inner!, item, serializer);
        }
        break;
      case 'option':
        if (value == null) {
          serializer.writeU8(0);
        } else {
          serializer.writeU8(1);
          _encodeValue(type.inner!, value, serializer);
        }
        break;
      case 'array':
        final list = value as List;
        if (list.length != type.size) {
          throw EventCoderException(
              'Array length mismatch: expected ${type.size}, got ${list.length}');
        }
        for (final item in list) {
          _encodeValue(type.inner!, item, serializer);
        }
        break;
      case 'defined':
        final typeName = type.defined;
        if (typeName == null) {
          throw const EventCoderException('Defined type missing name');
        }
        final nestedTypeDef = idl.types?.firstWhere(
          (t) => t.name == typeName,
          orElse: () => throw EventCoderException('Type not found: $typeName'),
        );
        if (nestedTypeDef != null) {
          final encodedNested = _encodeEventData(nestedTypeDef, value);
          final currentBytes = serializer.toBytes();
          serializer.clear();
          // Write current bytes back and add nested data
          for (final byte in currentBytes) {
            serializer.writeU8(byte);
          }
          for (final byte in encodedNested) {
            serializer.writeU8(byte);
          }
        }
        break;
      default:
        throw EventCoderException(
          'Unsupported type for encoding: ${type.kind}',
        );
    }
  }
}

/// Internal event layout information
class EventLayout {
  const EventLayout({
    required this.discriminator,
    required this.event,
    required this.typeDef,
  });

  /// The event discriminator bytes
  final List<int> discriminator;

  /// The IDL event definition
  final IdlEvent event;

  /// The IDL type definition for this event
  final IdlTypeDef typeDef;
}

/// Exception thrown by event coder operations
class EventCoderException extends AnchorException {
  const EventCoderException(super.message, [super.cause]);
}
