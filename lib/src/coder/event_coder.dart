/// Event coder implementation for Anchor and Quasar programs
///
/// This module provides the EventCoder interface and implementations
/// for parsing and decoding program events from transaction logs.
///
/// Supports two event formats:
/// - **Anchor**: SHA256("event:{name}") 8-byte discriminators, Borsh data
/// - **Quasar**: `0xFF` prefix + explicit N-byte discriminators, repr(C) data
library;

import 'package:coral_xyz/src/idl/idl.dart';
import 'package:coral_xyz/src/coder/borsh_types.dart';
import 'package:coral_xyz/src/coder/discriminator_computer.dart';
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
///
/// Supports both Anchor and Quasar event formats:
/// - **Anchor**: `[8-byte SHA256 disc | Borsh data]`
/// - **Quasar**: `[0xFF | N-byte explicit disc | repr(C) data]`
///
/// For Quasar events the leading `0xFF` byte is stripped before
/// discriminator matching. The explicit discriminator length comes
/// from the IDL's `event.discriminator` array.
class BorshEventCoder implements EventCoder {
  /// Create a new BorshEventCoder
  BorshEventCoder(this.idl, [this.programId]) {
    _eventLayouts = _buildEventLayouts();
  }

  /// The IDL containing event definitions
  final Idl idl;

  /// The program ID associated with events
  final PublicKey? programId;

  /// Whether this IDL uses Quasar-style events (0xFF prefix + explicit disc)
  bool get isQuasar => idl.isQuasar;

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

    // For Quasar events the on-chain format is [0xFF | disc | data].
    // The `__handle_event` handler already strips the 0xFF before logging
    // (it calls `log_data(&[&instruction_data[1..]])`), so log data is
    // [disc | data].  However, if the caller passes the raw CPI instruction
    // data we must tolerate the prefix as well.
    Uint8List payload = logData;
    if (payload.isNotEmpty &&
        payload[0] == DiscriminatorComputer.quasarEventPrefix) {
      payload = payload.sublist(1);
    }

    // Try to match against known event discriminators
    for (final entry in _eventLayouts.entries) {
      final eventName = entry.key;
      final layout = entry.value;
      final disc = layout.discriminator;

      if (disc.isEmpty || payload.length < disc.length) {
        continue;
      }

      // Check if discriminator matches
      bool matches = true;
      for (int i = 0; i < disc.length; i++) {
        if (payload[i] != disc[i]) {
          matches = false;
          break;
        }
      }

      if (matches) {
        try {
          // Skip discriminator and decode the event data
          final eventData = payload.sublist(disc.length);
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

    final discriminator = Uint8List.fromList(layout.discriminator);
    final encodedData = _encodeEventData(layout.typeDef, eventData);

    // Quasar events are encoded as [0xFF | disc | data] for CPI emission.
    // Anchor events stay as [disc | data].
    final prefix = isQuasar ? 1 : 0;
    final totalLength = prefix + discriminator.length + encodedData.length;
    final result = Uint8List(totalLength);
    var offset = 0;
    if (isQuasar) {
      result[0] = DiscriminatorComputer.quasarEventPrefix;
      offset = 1;
    }
    result.setRange(offset, offset + discriminator.length, discriminator);
    result.setRange(offset + discriminator.length, result.length, encodedData);

    return result;
  }

  /// Build event layouts from IDL
  ///
  /// For Anchor: discriminators come from `event.discriminator` (pre-computed
  /// SHA256) or are computed via SHA256("event:{name}").
  /// For Quasar: discriminators are explicit byte arrays from the IDL.
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

      // Resolve discriminator: use explicit bytes from IDL when present,
      // fall back to SHA256("event:{name}") for Anchor.
      final disc = DiscriminatorComputer.resolve(
        prefix: DiscriminatorComputer.eventPrefix,
        name: event.name,
        explicit: event.discriminator,
      );

      layouts[event.name] = EventLayout(
        discriminator: disc.toList(),
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
      case 'dynString':
        return deserializer.readString();
      case 'pubkey':
      case 'publicKey':
        return PublicKeyUtils.fromBytes(
          Uint8List.fromList(deserializer.readBytes(32)),
        );
      case 'vec':
      case 'dynVec':
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
      case 'tail':
        // Consume all remaining bytes
        return deserializer.readRemainingBytes();
      case 'defined':
        // Handle user-defined types (nested structs)
        final definedType = type.defined;
        if (definedType == null) {
          throw const EventCoderException('Defined type missing name');
        }
        final nestedTypeDef = idl.types?.firstWhere(
          (t) => t.name == definedType.name,
          orElse: () =>
              throw EventCoderException('Type not found: ${definedType.name}'),
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
          'Event data must be a Map for struct type',
        );
      }
      return serializer.toBytes();
    } else {
      throw EventCoderException(
        'Unsupported event type for encoding: ${typeSpec.kind}',
      );
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
      case 'dynString':
        serializer.writeString(value as String);
        break;
      case 'pubkey':
      case 'publicKey':
        // Write 32 raw bytes for public keys
        final PublicKey pk;
        if (value is PublicKey) {
          pk = value;
        } else if (value is String) {
          pk = PublicKey.fromBase58(value);
        } else {
          throw EventCoderException(
            'Cannot encode publicKey from ${value.runtimeType}',
          );
        }
        for (final byte in pk.toBytes()) {
          serializer.writeU8(byte);
        }
        break;
      case 'vec':
      case 'dynVec':
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
            'Array length mismatch: expected ${type.size}, got ${list.length}',
          );
        }
        for (final item in list) {
          _encodeValue(type.inner!, item, serializer);
        }
        break;
      case 'tail':
        // Write raw bytes
        final bytes = value as List<int>;
        for (final byte in bytes) {
          serializer.writeU8(byte);
        }
        break;
      case 'defined':
        final encDefinedType = type.defined;
        if (encDefinedType == null) {
          throw const EventCoderException('Defined type missing name');
        }
        final nestedTypeDef = idl.types?.firstWhere(
          (t) => t.name == encDefinedType.name,
          orElse: () => throw EventCoderException(
            'Type not found: ${encDefinedType.name}',
          ),
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
