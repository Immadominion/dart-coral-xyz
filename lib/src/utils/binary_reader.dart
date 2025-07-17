import 'dart:convert';
import 'dart:typed_data';

/// Binary reader for deserializing data in little-endian format
class BinaryReader {
  BinaryReader(this.buf);

  int offset = 0;
  final ByteData buf;

  /// Read a single byte (u8)
  int readU8() {
    final value = buf.getUint8(offset);
    offset += 1;
    return value;
  }

  /// Read a 16-bit unsigned integer (u16)
  int readU16() {
    final value = buf.getUint16(offset, Endian.little);
    offset += 2;
    return value;
  }

  /// Read a 32-bit unsigned integer (u32)
  int readU32() {
    final value = buf.getUint32(offset, Endian.little);
    offset += 4;
    return value;
  }

  /// Read a 64-bit unsigned integer (u64)
  BigInt readU64() {
    final buffer = _readBuffer(8);
    return _decodeBigInt(buffer, isSigned: false);
  }

  /// Read a string with length prefix
  String readString() {
    final len = readU32();
    final buffer = _readBuffer(len);
    return utf8.decode(buffer);
  }

  /// Read a boolean value
  bool readBool() => readU8() != 0;

  /// Read a signed 8-bit integer (i8)
  int readI8() {
    final value = readU8();
    return value > 127 ? value - 256 : value;
  }

  /// Read a signed 16-bit integer (i16)
  int readI16() {
    final value = readU16();
    return value > 32767 ? value - 65536 : value;
  }

  /// Read a signed 32-bit integer (i32)
  int readI32() {
    final value = readU32();
    return value > 2147483647 ? value - 4294967296 : value;
  }

  /// Read a signed 64-bit integer (i64)
  BigInt readI64() {
    final value = readU64();
    final max = BigInt.from(9223372036854775807);
    return value > max ? value - (BigInt.one << 64) : value;
  }

  /// Read a 128-bit unsigned integer (u128)
  BigInt readU128() {
    final buffer = _readBuffer(16);
    return _decodeBigInt(buffer, isSigned: false);
  }

  /// Read a signed 128-bit integer (i128)
  BigInt readI128() {
    final buffer = _readBuffer(16);
    return _decodeBigInt(buffer, isSigned: true);
  }

  /// Read a 32-bit float (f32)
  double readF32() {
    final value = buf.getFloat32(offset, Endian.little);
    offset += 4;
    return value;
  }

  /// Read a 64-bit float (f64)
  double readF64() {
    final value = buf.getFloat64(offset, Endian.little);
    offset += 8;
    return value;
  }

  /// Read raw bytes
  List<int> readBytes(int length) {
    return _readBuffer(length);
  }

  /// Read a vector with a length prefix
  List<T> readVec<T>(T Function() readElement) {
    final length = readU32();
    final result = <T>[];
    for (int i = 0; i < length; i++) {
      result.add(readElement());
    }
    return result;
  }

  /// Read an optional value
  T? readOption<T>(T Function() readElement) {
    final hasValue = readBool();
    return hasValue ? readElement() : null;
  }

  List<int> _readBuffer(int len) {
    if (offset + len > buf.lengthInBytes) {
      throw RangeError('Buffer overflow');
    }
    final buffer = buf.buffer.asUint8List().sublist(offset, offset + len);
    offset += len;
    return buffer;
  }

  BigInt _decodeBigInt(List<int> bytes, {required bool isSigned}) {
    BigInt result = BigInt.zero;
    for (int i = bytes.length - 1; i >= 0; i--) {
      result = (result << 8) | BigInt.from(bytes[i]);
    }
    if (isSigned && bytes.isNotEmpty && bytes.last & 0x80 != 0) {
      result = result - (BigInt.one << (bytes.length * 8));
    }
    return result;
  }
}
