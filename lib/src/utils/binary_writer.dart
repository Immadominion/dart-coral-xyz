import 'dart:convert';
import 'dart:typed_data';

/// Binary writer for serializing data in little-endian format
class BinaryWriter {
  static const int _initialLength = 1024;

  ByteData _buf = ByteData(_initialLength);
  int _length = 0;

  /// Get the current buffer as bytes
  Uint8List get bytes => _buf.buffer.asUint8List().sublist(0, _length);

  void _maybeResize() {
    if (_buf.lengthInBytes >= 16 + _length) return;
    final list = Uint8List.fromList([
      ..._buf.buffer.asUint8List().take(_length),
      ...Uint8List(_initialLength)
    ]);
    _buf = list.buffer.asByteData();
  }

  /// Write a single byte (u8)
  void writeU8(int value) {
    _maybeResize();
    _buf.setUint8(_length, value);
    _length += 1;
  }

  /// Write a single byte (deprecated - use writeU8)
  void writeByte(int value) => writeU8(value);

  /// Write a 16-bit unsigned integer (u16)
  void writeU16(int value) {
    _maybeResize();
    _buf.setUint16(_length, value, Endian.little);
    _length += 2;
  }

  /// Write a 32-bit unsigned integer (u32)
  void writeU32(int value) {
    _maybeResize();
    _buf.setUint32(_length, value, Endian.little);
    _length += 4;
  }

  /// Write a boolean value
  void writeBool(bool value) => writeU8(value ? 1 : 0);

  /// Write a signed 8-bit integer (i8)
  void writeI8(int value) {
    if (value < -128 || value > 127) {
      throw ArgumentError('Value out of i8 range: $value');
    }
    writeU8(value < 0 ? value + 256 : value);
  }

  /// Write a signed 16-bit integer (i16)
  void writeI16(int value) {
    if (value < -32768 || value > 32767) {
      throw ArgumentError('Value out of i16 range: $value');
    }
    writeU16(value < 0 ? value + 65536 : value);
  }

  /// Write a signed 32-bit integer (i32)
  void writeI32(int value) {
    if (value < -2147483648 || value > 2147483647) {
      throw ArgumentError('Value out of i32 range: $value');
    }
    writeU32(value < 0 ? value + 4294967296 : value);
  }

  /// Write a signed 64-bit integer (i64)
  void writeI64(BigInt value) {
    final min = BigInt.from(-9223372036854775808);
    final max = BigInt.from(9223372036854775807);
    if (value < min || value > max) {
      throw ArgumentError('Value out of i64 range: $value');
    }
    writeU64(value < BigInt.zero ? value + (BigInt.one << 64) : value);
  }

  /// Write a 128-bit unsigned integer (u128)
  void writeU128(BigInt value) {
    final buffer = _encodeBigIntAsUnsigned(value, 16);
    _writeBuffer(buffer);
  }

  /// Write a signed 128-bit integer (i128)
  void writeI128(BigInt value) {
    final max = (BigInt.one << 127) - BigInt.one;
    final min = -(BigInt.one << 127);
    if (value < min || value > max) {
      throw ArgumentError('Value out of i128 range: $value');
    }
    final buffer = _encodeBigIntAsUnsigned(
      value < BigInt.zero ? value + (BigInt.one << 128) : value,
      16,
    );
    _writeBuffer(buffer);
  }

  /// Write a 32-bit float (f32)
  void writeF32(double value) {
    _maybeResize();
    _buf.setFloat32(_length, value, Endian.little);
    _length += 4;
  }

  /// Write a 64-bit float (f64)
  void writeF64(double value) {
    _maybeResize();
    _buf.setFloat64(_length, value, Endian.little);
    _length += 8;
  }

  /// Write raw bytes
  void writeBytes(List<int> bytes) {
    _writeBuffer(bytes);
  }

  /// Write a vector with a length prefix
  void writeVec<T>(List<T> items, void Function(T) writeElement) {
    writeU32(items.length);
    for (final item in items) {
      writeElement(item);
    }
  }

  /// Write a compact u16 length prefix
  void writeCompactU16(int length) {
    if (length >= 0x4000) {
      throw ArgumentError('Length too large: $length');
    }

    if (length >= 0x80) {
      writeU8(((length >> 8) & 0x3F) | 0x80);
      writeU8(length & 0xFF);
    } else {
      writeU8(length);
    }
  }

  /// Write a compact array of bytes with length prefix
  void writeCompactArray(List<int> array) {
    writeCompactU16(array.length);
    writeBytes(array);
  }

  /// Write an optional value
  void writeOption<T>(T? value, void Function(T) writeElement) {
    if (value != null) {
      writeBool(true);
      writeElement(value);
    } else {
      writeBool(false);
    }
  }

  /// Write a 64-bit unsigned integer (u64)
  void writeU64(BigInt value) {
    final buffer = _encodeBigIntAsUnsigned(value, 8);
    _writeBuffer(buffer);
  }

  /// Write a string with length prefix
  void writeString(String value) {
    final bytes = utf8.encode(value);
    writeU32(bytes.length);
    _writeBuffer(bytes);
  }

  /// Write raw bytes
  void write(List<int> bytes) {
    _writeBuffer(bytes);
  }

  void _writeBuffer(Iterable<int> buffer) {
    final list = Uint8List.fromList([
      ..._buf.buffer.asUint8List().take(_length),
      ...buffer,
      ...Uint8List(_initialLength),
    ]);
    _buf = list.buffer.asByteData();
    _length += buffer.length;
  }

  List<int> _encodeBigIntAsUnsigned(BigInt value, int byteLength) {
    final bytes = <int>[];
    BigInt temp = value;
    for (int i = 0; i < byteLength; i++) {
      bytes.add((temp & BigInt.from(0xFF)).toInt());
      temp = temp >> 8;
    }
    return bytes;
  }

  /// Get the current buffer as bytes
  Uint8List toArray() => bytes;
}
