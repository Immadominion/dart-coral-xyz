/// Shared verification harness for coral_xyz framework testing.
///
/// Provides utilities for loading real IDLs, comparing outputs,
/// and recording verification results across Anchor, Quasar, and Pinocchio.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:coral_xyz/src/idl/idl.dart';

/// Load an IDL JSON file from the fixtures directory.
Idl loadFixtureIdl(String filename) {
  final file = File('test/verification/fixtures/$filename');
  if (!file.existsSync()) {
    throw StateError('Fixture not found: $filename');
  }
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return Idl.fromJson(json);
}

/// Load raw IDL JSON from the fixtures directory.
Map<String, dynamic> loadFixtureJson(String filename) {
  final file = File('test/verification/fixtures/$filename');
  if (!file.existsSync()) {
    throw StateError('Fixture not found: $filename');
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

/// Convert a list of ints to Uint8List for comparison.
Uint8List toBytes(List<int> bytes) => Uint8List.fromList(bytes);

/// Format bytes as hex string for readable assertion messages.
String bytesToHex(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// A single verification result for tracking what was tested.
class VerificationResult {
  VerificationResult({
    required this.capability,
    required this.framework,
    required this.passed,
    this.detail,
    this.error,
  });

  final String capability;
  final String framework;
  final bool passed;
  final String? detail;
  final String? error;

  @override
  String toString() {
    final status = passed ? 'PASS' : 'FAIL';
    final msg = '[$status] $framework: $capability';
    if (error != null) return '$msg — $error';
    if (detail != null) return '$msg — $detail';
    return msg;
  }
}

/// Accumulates verification results for a test run.
class VerificationReport {
  final List<VerificationResult> results = [];

  void record(VerificationResult result) {
    results.add(result);
    // Print immediately so we see progress in test output
    print(result);
  }

  void pass(String framework, String capability, {String? detail}) {
    record(
      VerificationResult(
        capability: capability,
        framework: framework,
        passed: true,
        detail: detail,
      ),
    );
  }

  void fail(String framework, String capability, {String? error}) {
    record(
      VerificationResult(
        capability: capability,
        framework: framework,
        passed: false,
        error: error,
      ),
    );
  }

  int get passCount => results.where((r) => r.passed).length;
  int get failCount => results.where((r) => !r.passed).length;
  int get total => results.length;

  void printSummary() {
    print('\n=== Verification Summary ===');
    print('Total: $total | Pass: $passCount | Fail: $failCount');
    if (failCount > 0) {
      print('\nFailures:');
      for (final r in results.where((r) => !r.passed)) {
        print('  $r');
      }
    }
    print('============================\n');
  }
}
