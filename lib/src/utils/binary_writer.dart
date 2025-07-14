import 'dart:typed_data';

/// Utility class for writing binary data with Solana serialization format
class BinaryWriter {
  final BytesBuilder _buffer = BytesBuilder();

  /// Write a single byte
  void writeByte(int value) {
    if (value < 0 || value > 255) {
      throw ArgumentError('Value out of byte range: $value');
    }
    _buffer.addByte(value);
  }

  /// Write a uint32
  void writeUint32(int value) {
    if (value < 0 || value > 0xFFFFFFFF) {
      throw ArgumentError('Value out of uint32 range: $value');
    }

    final bytes = Uint8List(4);
    bytes[0] = value & 0xFF;
    bytes[1] = (value >> 8) & 0xFF;
    bytes[2] = (value >> 16) & 0xFF;
    bytes[3] = (value >> 24) & 0xFF;
    _buffer.add(bytes);
  }

  /// Write a compact-u16 length prefix
  void writeCompactU16(int length) {
    if (length >= 0x4000) {
      throw ArgumentError('Length too large: $length');
    }

    if (length >= 0x80) {
      writeByte(((length >> 8) & 0x3F) | 0x80);
      writeByte(length & 0xFF);
    } else {
      writeByte(length);
    }
  }

  /// Write a compact-array of bytes with length prefix
  void writeCompactArray(List<int> array) {
    writeCompactU16(array.length);
    _buffer.add(Uint8List.fromList(array));
  }

  /// Write raw bytes
  void write(List<int> bytes) {
    _buffer.add(bytes);
  }

  /// Get the serialized bytes
  Uint8List toArray() => _buffer.takeBytes();
}
