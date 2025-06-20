/// Borsh serialization system for Anchor programs
///
/// This module implements the Borsh (Binary Object Representation Serializer for Hashing)
/// specification used by Solana and Anchor programs. It provides type-safe serialization
/// and deserialization of data structures.
///
/// Based on the Borsh specification at: https://borsh.io/

import 'dart:typed_data';
import 'dart:convert';

/// Interface for Borsh-serializable types
abstract class BorshSerializable {
  /// Serialize this object to bytes using Borsh format
  Uint8List serialize();

  /// Get the serialized size in bytes
  int get serializedSize;
}

/// Interface for Borsh-deserializable types
abstract class BorshDeserializable<T> {
  /// Deserialize bytes to create an instance of type T
  T deserialize(Uint8List data);
}

/// Main Borsh serializer and deserializer
class BorshSerializer {
  final List<int> _buffer = [];

  /// Create a new serializer
  BorshSerializer();

  /// Get the serialized bytes
  Uint8List toBytes() => Uint8List.fromList(_buffer);

  /// Clear the buffer
  void clear() => _buffer.clear();

  /// Serialize a u8 (unsigned 8-bit integer)
  void writeU8(int value) {
    if (value < 0 || value > 255) {
      throw BorshException('u8 value must be between 0 and 255, got: $value');
    }
    _buffer.add(value);
  }

  /// Serialize a u16 (unsigned 16-bit integer, little endian)
  void writeU16(int value) {
    if (value < 0 || value > 65535) {
      throw BorshException(
          'u16 value must be between 0 and 65535, got: $value');
    }
    _buffer.add(value & 0xFF);
    _buffer.add((value >> 8) & 0xFF);
  }

  /// Serialize a u32 (unsigned 32-bit integer, little endian)
  void writeU32(int value) {
    if (value < 0 || value > 4294967295) {
      throw BorshException(
          'u32 value must be between 0 and 4294967295, got: $value');
    }
    _buffer.add(value & 0xFF);
    _buffer.add((value >> 8) & 0xFF);
    _buffer.add((value >> 16) & 0xFF);
    _buffer.add((value >> 24) & 0xFF);
  }

  /// Serialize a u64 (unsigned 64-bit integer, little endian)
  void writeU64(int value) {
    if (value < 0) {
      throw BorshException('u64 value must be non-negative, got: $value');
    }
    // Handle 64-bit integers by splitting into two 32-bit parts
    final low = value & 0xFFFFFFFF;
    final high = (value >> 32) & 0xFFFFFFFF;
    writeU32(low);
    writeU32(high);
  }

  /// Serialize an i8 (signed 8-bit integer)
  void writeI8(int value) {
    if (value < -128 || value > 127) {
      throw BorshException(
          'i8 value must be between -128 and 127, got: $value');
    }
    _buffer.add(value < 0 ? value + 256 : value);
  }

  /// Serialize an i16 (signed 16-bit integer, little endian)
  void writeI16(int value) {
    if (value < -32768 || value > 32767) {
      throw BorshException(
          'i16 value must be between -32768 and 32767, got: $value');
    }
    final unsigned = value < 0 ? value + 65536 : value;
    _buffer.add(unsigned & 0xFF);
    _buffer.add((unsigned >> 8) & 0xFF);
  }

  /// Serialize an i32 (signed 32-bit integer, little endian)
  void writeI32(int value) {
    if (value < -2147483648 || value > 2147483647) {
      throw BorshException(
          'i32 value must be between -2147483648 and 2147483647, got: $value');
    }
    final unsigned = value < 0 ? value + 4294967296 : value;
    _buffer.add(unsigned & 0xFF);
    _buffer.add((unsigned >> 8) & 0xFF);
    _buffer.add((unsigned >> 16) & 0xFF);
    _buffer.add((unsigned >> 24) & 0xFF);
  }

  /// Serialize an i64 (signed 64-bit integer, little endian)
  void writeI64(int value) {
    if (value < -9223372036854775808 || value > 9223372036854775807) {
      throw BorshException(
          'i64 value must be between -9223372036854775808 and 9223372036854775807, got: $value');
    }
    // Convert to bytes using ByteData for proper signed integer handling
    final data = ByteData(8);
    data.setInt64(0, value, Endian.little);
    _buffer.addAll(data.buffer.asUint8List());
  }

  /// Serialize a boolean
  void writeBool(bool value) {
    _buffer.add(value ? 1 : 0);
  }

  /// Serialize a string (length-prefixed UTF-8)
  void writeString(String value) {
    final utf8Bytes = utf8.encode(value);
    writeU32(utf8Bytes.length);
    _buffer.addAll(utf8Bytes);
  }

  /// Serialize a fixed-size array of bytes
  void writeFixedArray(Uint8List bytes) {
    _buffer.addAll(bytes);
  }

  /// Serialize a variable-size array (length-prefixed)
  void writeArray<T>(List<T> items, void Function(T) writeItem) {
    writeU32(items.length);
    for (final item in items) {
      writeItem(item);
    }
  }

  /// Serialize an optional value
  void writeOption<T>(T? value, void Function(T) writeValue) {
    if (value == null) {
      writeU8(0); // None variant
    } else {
      writeU8(1); // Some variant
      writeValue(value);
    }
  }
}

/// Borsh deserializer
class BorshDeserializer {
  final Uint8List _data;
  int _offset = 0;

  /// Create a deserializer for the given data
  BorshDeserializer(this._data);

  /// Get remaining bytes in the buffer
  int get remaining => _data.length - _offset;

  /// Check if there are more bytes to read
  bool get hasMore => _offset < _data.length;

  /// Read a u8 (unsigned 8-bit integer)
  int readU8() {
    if (_offset >= _data.length) {
      throw BorshException('Not enough bytes to read u8');
    }
    return _data[_offset++];
  }

  /// Read a u16 (unsigned 16-bit integer, little endian)
  int readU16() {
    if (_offset + 2 > _data.length) {
      throw BorshException('Not enough bytes to read u16');
    }
    final value = _data[_offset] | (_data[_offset + 1] << 8);
    _offset += 2;
    return value;
  }

  /// Read a u32 (unsigned 32-bit integer, little endian)
  int readU32() {
    if (_offset + 4 > _data.length) {
      throw BorshException('Not enough bytes to read u32');
    }
    final value = _data[_offset] |
        (_data[_offset + 1] << 8) |
        (_data[_offset + 2] << 16) |
        (_data[_offset + 3] << 24);
    _offset += 4;
    return value;
  }

  /// Read a u64 (unsigned 64-bit integer, little endian)
  int readU64() {
    final low = readU32();
    final high = readU32();
    return low | (high << 32);
  }

  /// Read an i8 (signed 8-bit integer)
  int readI8() {
    final value = readU8();
    return value > 127 ? value - 256 : value;
  }

  /// Read an i16 (signed 16-bit integer, little endian)
  int readI16() {
    final low = readU8();
    final high = readU8();
    final unsigned = low | (high << 8);
    return unsigned > 32767 ? unsigned - 65536 : unsigned;
  }

  /// Read an i32 (signed 32-bit integer, little endian)
  int readI32() {
    final b1 = readU8();
    final b2 = readU8();
    final b3 = readU8();
    final b4 = readU8();
    final unsigned = b1 | (b2 << 8) | (b3 << 16) | (b4 << 24);
    return unsigned > 2147483647 ? unsigned - 4294967296 : unsigned;
  }

  /// Read an i64 (signed 64-bit integer, little endian)
  int readI64() {
    if (_offset + 8 > _data.length) {
      throw BorshException('Not enough bytes to read i64');
    }
    final bytes =
        Uint8List.fromList(_data.getRange(_offset, _offset + 8).toList());
    _offset += 8;
    final data = ByteData.sublistView(bytes);
    return data.getInt64(0, Endian.little);
  }

  /// Read a boolean
  bool readBool() {
    final value = readU8();
    if (value != 0 && value != 1) {
      throw BorshException('Invalid boolean value: $value');
    }
    return value == 1;
  }

  /// Read a string (length-prefixed UTF-8)
  String readString() {
    final length = readU32();
    if (_offset + length > _data.length) {
      throw BorshException('Not enough bytes to read string of length $length');
    }
    final bytes = _data.sublist(_offset, _offset + length);
    _offset += length;
    return utf8.decode(bytes);
  }

  /// Read a fixed-size array of bytes
  Uint8List readFixedArray(int length) {
    if (_offset + length > _data.length) {
      throw BorshException(
          'Not enough bytes to read fixed array of length $length');
    }
    final result = _data.sublist(_offset, _offset + length);
    _offset += length;
    return result;
  }

  /// Read a variable-size array (length-prefixed)
  List<T> readArray<T>(T Function() readItem) {
    final length = readU32();
    final result = <T>[];
    for (int i = 0; i < length; i++) {
      result.add(readItem());
    }
    return result;
  }

  /// Read an optional value
  T? readOption<T>(T Function() readValue) {
    final hasValue = readU8();
    if (hasValue == 0) {
      return null; // None variant
    } else if (hasValue == 1) {
      return readValue(); // Some variant
    } else {
      throw BorshException('Invalid option tag: $hasValue');
    }
  }
}

/// Exception thrown by Borsh operations
class BorshException implements Exception {
  final String message;

  const BorshException(this.message);

  @override
  String toString() => 'BorshException: $message';
}
