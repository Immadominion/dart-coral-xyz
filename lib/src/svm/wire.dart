/// Binary wire format for passing instructions, accounts, and results across FFI.
///
/// All integers are little-endian. All lengths are u32 except lamports (u64).
/// This matches the Rust wire format in `quasar-svm/ffi/src/wire.rs` exactly.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../types/public_key.dart';
import '../types/transaction.dart';
import 'execution_result.dart';

// ---------------------------------------------------------------------------
// Wire Reader — offset-based, zero-copy over a Uint8List
// ---------------------------------------------------------------------------

class _WireReader {
  _WireReader(this._data) : _byteData = ByteData.sublistView(_data);

  final Uint8List _data;
  final ByteData _byteData;
  int _pos = 0;

  int get remaining => _data.length - _pos;

  Uint8List readBytes(int n) {
    if (_pos + n > _data.length) {
      throw StateError(
        'Wire read overflow: need $n bytes at $_pos, have ${_data.length}',
      );
    }
    final slice = Uint8List.sublistView(_data, _pos, _pos + n);
    _pos += n;
    return slice;
  }

  int readU8() {
    if (_pos >= _data.length) {
      throw StateError('Wire read overflow: need 1 byte at $_pos');
    }
    return _data[_pos++];
  }

  bool readBool() => readU8() != 0;

  int readU32() {
    final v = _byteData.getUint32(_pos, Endian.little);
    _pos += 4;
    return v;
  }

  int readI32() {
    final v = _byteData.getInt32(_pos, Endian.little);
    _pos += 4;
    return v;
  }

  int readU64() {
    // Dart int is 64-bit on native platforms
    final lo = _byteData.getUint32(_pos, Endian.little);
    final hi = _byteData.getUint32(_pos + 4, Endian.little);
    _pos += 8;
    return (hi << 32) | lo;
  }

  double readF64() {
    final v = _byteData.getFloat64(_pos, Endian.little);
    _pos += 8;
    return v;
  }

  List<int> readPubkeyBytes() {
    return List<int>.from(readBytes(32));
  }

  String readLengthPrefixedUtf8() {
    final len = readU32();
    if (len == 0) return '';
    final bytes = readBytes(len);
    return utf8.decode(bytes);
  }
}

// ---------------------------------------------------------------------------
// Wire Writer — growing buffer
// ---------------------------------------------------------------------------

class _WireWriter {
  final _builder = BytesBuilder(copy: false);
  final _buf4 = Uint8List(4);
  final _buf8 = Uint8List(8);

  void writeU8(int v) {
    _builder.addByte(v);
  }

  void writeBool(bool v) {
    _builder.addByte(v ? 1 : 0);
  }

  void writeU32(int v) {
    final bd = ByteData.sublistView(_buf4);
    bd.setUint32(0, v, Endian.little);
    _builder.add(Uint8List.fromList(_buf4));
  }

  void writeU64(int v) {
    final bd = ByteData.sublistView(_buf8);
    bd.setUint32(0, v & 0xFFFFFFFF, Endian.little);
    bd.setUint32(4, (v >> 32) & 0xFFFFFFFF, Endian.little);
    _builder.add(Uint8List.fromList(_buf8));
  }

  void writeBytes(Uint8List data) {
    _builder.add(data);
  }

  void writeBytesFromList(List<int> data) {
    _builder.add(Uint8List.fromList(data));
  }

  void writeLengthPrefixed(Uint8List data) {
    writeU32(data.length);
    _builder.add(data);
  }

  Uint8List toBytes() => _builder.toBytes();
}

// ---------------------------------------------------------------------------
// Instruction Serialization (Dart → C)
// ---------------------------------------------------------------------------

/// Serialize a single instruction into the wire format.
Uint8List serializeInstruction(TransactionInstruction ix) {
  final w = _WireWriter();

  // program_id (32 bytes)
  w.writeBytesFromList(ix.programId.bytes);

  // data (length-prefixed)
  w.writeLengthPrefixed(ix.data);

  // account metas
  w.writeU32(ix.accounts.length);
  for (final meta in ix.accounts) {
    w.writeBytesFromList(meta.pubkey.bytes);
    w.writeBool(meta.isSigner);
    w.writeBool(meta.isWritable);
  }

  return w.toBytes();
}

/// Serialize multiple instructions with a count prefix.
Uint8List serializeInstructions(List<TransactionInstruction> instructions) {
  final w = _WireWriter();
  w.writeU32(instructions.length);
  for (final ix in instructions) {
    final ixBytes = serializeInstruction(ix);
    w.writeBytes(ixBytes);
  }
  return w.toBytes();
}

// ---------------------------------------------------------------------------
// Account Serialization (Dart → C)
// ---------------------------------------------------------------------------

/// Serialize accounts with a count prefix.
Uint8List serializeAccounts(List<KeyedAccount> accounts) {
  final w = _WireWriter();
  w.writeU32(accounts.length);
  for (final a in accounts) {
    // pubkey (32)
    w.writeBytesFromList(a.address.bytes);
    // owner (32)
    w.writeBytesFromList(a.owner.bytes);
    // lamports (u64)
    w.writeU64(a.lamports);
    // data (length-prefixed)
    w.writeLengthPrefixed(a.data);
    // executable (bool)
    w.writeBool(a.executable);
  }
  return w.toBytes();
}

// ---------------------------------------------------------------------------
// Result Deserialization (C → Dart)
// ---------------------------------------------------------------------------

/// Deserialize execution result from the wire format.
/// Matches the Rust `serialize_result` in `ffi/src/wire.rs` exactly.
ExecutionResult deserializeResult(Uint8List data) {
  final r = _WireReader(data);

  // Status
  final rawStatus = r.readI32();

  // Compute units and time
  final computeUnits = r.readU64();
  final executionTimeUs = r.readU64();

  // Return data
  final returnDataLen = r.readU32();
  final returnData = r.readBytes(returnDataLen);

  // Accounts
  final numAccounts = r.readU32();
  final accounts = <KeyedAccount>[];
  for (var i = 0; i < numAccounts; i++) {
    final address = PublicKeyUtils.fromBytes(r.readPubkeyBytes());
    final owner = PublicKeyUtils.fromBytes(r.readPubkeyBytes());
    final lamports = r.readU64();
    final dataLen = r.readU32();
    final accountData = Uint8List.fromList(r.readBytes(dataLen));
    final executable = r.readBool();
    accounts.add(
      KeyedAccount(
        address: address,
        owner: owner,
        lamports: lamports,
        data: accountData,
        executable: executable,
      ),
    );
  }

  // Logs
  final numLogs = r.readU32();
  final logs = <String>[];
  for (var i = 0; i < numLogs; i++) {
    logs.add(r.readLengthPrefixedUtf8());
  }

  // Error message
  final errorMessageLen = r.readU32();
  final errorMessage = errorMessageLen > 0
      ? utf8.decode(r.readBytes(errorMessageLen))
      : null;

  // Pre balances
  final numPreBalances = r.readU32();
  final preBalances = <int>[];
  for (var i = 0; i < numPreBalances; i++) {
    preBalances.add(r.readU64());
  }

  // Post balances
  final numPostBalances = r.readU32();
  final postBalances = <int>[];
  for (var i = 0; i < numPostBalances; i++) {
    postBalances.add(r.readU64());
  }

  // Pre token balances
  final numPreTokenBalances = r.readU32();
  final preTokenBalances = <TokenBalance>[];
  for (var i = 0; i < numPreTokenBalances; i++) {
    preTokenBalances.add(_readTokenBalance(r));
  }

  // Post token balances
  final numPostTokenBalances = r.readU32();
  final postTokenBalances = <TokenBalance>[];
  for (var i = 0; i < numPostTokenBalances; i++) {
    postTokenBalances.add(_readTokenBalance(r));
  }

  // Execution trace
  final numTraceInstructions = r.readU32();
  final traceInstructions = <ExecutedInstruction>[];
  for (var i = 0; i < numTraceInstructions; i++) {
    final stackDepth = r.readU8();

    // Full instruction
    final programId = PublicKeyUtils.fromBytes(r.readPubkeyBytes());
    final numMetas = r.readU32();
    final metas = <AccountMeta>[];
    for (var j = 0; j < numMetas; j++) {
      final pubkey = PublicKeyUtils.fromBytes(r.readPubkeyBytes());
      final isSigner = r.readBool();
      final isWritable = r.readBool();
      metas.add(
        AccountMeta(pubkey: pubkey, isSigner: isSigner, isWritable: isWritable),
      );
    }
    final ixDataLen = r.readU32();
    final ixData = Uint8List.fromList(r.readBytes(ixDataLen));

    final cuConsumed = r.readU64();
    final result = r.readU64();

    traceInstructions.add(
      ExecutedInstruction(
        stackDepth: stackDepth,
        instruction: TransactionInstruction(
          programId: programId,
          accounts: metas,
          data: ixData,
        ),
        computeUnitsConsumed: cuConsumed,
        result: result,
      ),
    );
  }

  // Build status
  final ExecutionStatus status;
  if (rawStatus == 0) {
    status = ExecutionSuccess();
  } else {
    status = ExecutionFailure(
      error: svmProgramErrorFromStatus(rawStatus, errorMessage),
    );
  }

  return ExecutionResult(
    status: status,
    computeUnits: computeUnits,
    executionTimeUs: executionTimeUs,
    returnData: Uint8List.fromList(returnData),
    accounts: accounts,
    logs: logs,
    preBalances: preBalances,
    postBalances: postBalances,
    preTokenBalances: preTokenBalances,
    postTokenBalances: postTokenBalances,
    executionTrace: ExecutionTrace(instructions: traceInstructions),
  );
}

TokenBalance _readTokenBalance(_WireReader r) {
  final accountIndex = r.readU32();
  final mint = r.readLengthPrefixedUtf8();
  final hasOwner = r.readBool();
  final owner = hasOwner ? r.readLengthPrefixedUtf8() : null;
  final decimals = r.readU8();
  final amount = r.readLengthPrefixedUtf8();
  final hasUiAmount = r.readBool();
  final uiAmount = hasUiAmount ? r.readF64() : null;
  return TokenBalance(
    accountIndex: accountIndex,
    mint: mint,
    owner: owner,
    decimals: decimals,
    amount: amount,
    uiAmount: uiAmount,
  );
}
