/// Workspace functionality for managing Anchor programs and IDLs.
/// Provides TypeScript-like workspace management for multiple programs.
library;

import 'dart:convert';
import '../types/public_key.dart';
import '../types/keypair.dart';
import '../types/transaction.dart';
import '../idl/idl.dart';
import '../program/program_class.dart';
import '../provider/anchor_provider.dart';

/// TypeScript-like workspace for managing multiple Anchor programs
class Workspace {
  final Map<String, Program> _programs = {};
  final AnchorProvider _provider;
  final Map<String, Idl> _idls = {};

  Workspace(this._provider);

  /// Get provider instance
  AnchorProvider get provider => _provider;

  /// Get all program names
  List<String> get programNames => _programs.keys.toList();

  /// Get all programs
  Map<String, Program> get programs => Map.unmodifiable(_programs);

  /// Add a program to the workspace
  void addProgram(String name, Program program) {
    _programs[name] = program;
  }

  /// Get a program by name
  Program? getProgram(String name) {
    return _programs[name];
  }

  /// Remove a program from workspace
  bool removeProgram(String name) {
    return _programs.remove(name) != null;
  }

  /// Load program from IDL and program ID
  Future<Program> loadProgram(
    String name,
    Idl idl,
    PublicKey programId,
  ) async {
    final program = Program.withProgramId(
      idl,
      programId,
      provider: _provider,
    );

    _programs[name] = program;
    _idls[name] = idl;

    return program;
  }

  /// Load program from IDL JSON string
  Future<Program> loadProgramFromJson(
    String name,
    String idlJson,
    PublicKey programId,
  ) async {
    final idlMap = jsonDecode(idlJson) as Map<String, dynamic>;
    final idl = Idl.fromJson(idlMap);
    return loadProgram(name, idl, programId);
  }

  /// Load multiple programs from configuration
  Future<void> loadPrograms(Map<String, ProgramConfig> configs) async {
    for (final entry in configs.entries) {
      final name = entry.key;
      final config = entry.value;

      await loadProgram(name, config.idl, config.programId);
    }
  }

  /// Get IDL for a program
  Idl? getIdl(String programName) {
    return _idls[programName];
  }

  /// Check if program exists in workspace
  bool hasProgram(String name) {
    return _programs.containsKey(name);
  }

  /// Clear all programs from workspace
  void clear() {
    _programs.clear();
    _idls.clear();
  }

  /// Get program by program ID
  Program? getProgramById(PublicKey programId) {
    for (final program in _programs.values) {
      if (program.programId == programId) {
        return program;
      }
    }
    return null;
  }

  /// Create a new workspace from provider
  static Workspace create(AnchorProvider provider) {
    return Workspace(provider);
  }

  /// Create workspace with default connection
  static Future<Workspace> createDefault({
    String? endpoint,
    Keypair? payer,
  }) async {
    final provider = await AnchorProvider.local();
    return Workspace(provider);
  }

  /// Batch load programs from a workspace configuration file
  static Future<Workspace> fromConfig(
    AnchorProvider provider,
    Map<String, dynamic> config,
  ) async {
    final workspace = Workspace(provider);

    final programsConfig = config['programs'] as Map<String, dynamic>?;
    if (programsConfig != null) {
      for (final entry in programsConfig.entries) {
        final name = entry.key;
        final programConfig = entry.value as Map<String, dynamic>;

        final idlData = programConfig['idl'];
        final programIdStr = programConfig['programId'] as String?;

        if (idlData != null && programIdStr != null) {
          final programId = PublicKey.fromBase58(programIdStr);

          Idl idl;
          if (idlData is String) {
            // IDL as JSON string
            final idlMap = jsonDecode(idlData) as Map<String, dynamic>;
            idl = Idl.fromJson(idlMap);
          } else if (idlData is Map<String, dynamic>) {
            // IDL as object
            idl = Idl.fromJson(idlData);
          } else {
            throw ArgumentError('Invalid IDL format for program $name');
          }

          await workspace.loadProgram(name, idl, programId);
        }
      }
    }

    return workspace;
  }

  /// Export workspace configuration
  Map<String, dynamic> toConfig() {
    final programsConfig = <String, dynamic>{};

    for (final entry in _programs.entries) {
      final name = entry.key;
      final program = entry.value;
      final idl = _idls[name];

      if (idl != null) {
        programsConfig[name] = {
          'programId': program.programId.toBase58(),
          'idl': idl.toJson(),
        };
      }
    }

    return {
      'programs': programsConfig,
      'provider': {
        'cluster': 'local', // Since we can't access endpoint directly
      },
    };
  }

  /// Get all program IDs in the workspace
  List<PublicKey> getProgramIds() {
    return _programs.values.map((p) => p.programId).toList();
  }

  /// Validate all programs in workspace
  Future<Map<String, bool>> validatePrograms() async {
    final results = <String, bool>{};

    for (final entry in _programs.entries) {
      final name = entry.key;
      final program = entry.value;

      try {
        // Try to fetch account info to validate program exists
        final accountInfo = await _provider.connection.getAccountInfo(
          program.programId,
        );
        results[name] = accountInfo != null;
      } catch (e) {
        results[name] = false;
      }
    }

    return results;
  }

  /// Create a transaction with multiple programs
  Transaction createTransaction() {
    return Transaction(instructions: []);
  }

  /// Get workspace statistics
  WorkspaceStats getStats() {
    final programCount = _programs.length;
    final totalInstructions = _idls.values
        .map((idl) => idl.instructions.length)
        .fold(0, (a, b) => a + b);
    final totalAccounts = _idls.values
        .map((idl) => idl.accounts?.length ?? 0)
        .fold(0, (a, b) => a + b);

    return WorkspaceStats(
      programCount: programCount,
      totalInstructions: totalInstructions,
      totalAccounts: totalAccounts,
      programNames: _programs.keys.toList(),
    );
  }

  @override
  String toString() {
    return 'Workspace(programs: ${_programs.length}, provider: local)';
  }
}

/// Configuration for a single program in the workspace
class ProgramConfig {
  final Idl idl;
  final PublicKey programId;
  final String? name;
  final Map<String, dynamic>? metadata;

  const ProgramConfig({
    required this.idl,
    required this.programId,
    this.name,
    this.metadata,
  });

  /// Create from JSON configuration
  factory ProgramConfig.fromJson(Map<String, dynamic> json) {
    return ProgramConfig(
      idl: Idl.fromJson(json['idl'] as Map<String, dynamic>),
      programId: PublicKey.fromBase58(json['programId'] as String),
      name: json['name'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'idl': idl.toJson(),
      'programId': programId.toBase58(),
      if (name != null) 'name': name,
      if (metadata != null) 'metadata': metadata,
    };
  }
}

/// Statistics about the workspace
class WorkspaceStats {
  final int programCount;
  final int totalInstructions;
  final int totalAccounts;
  final List<String> programNames;

  const WorkspaceStats({
    required this.programCount,
    required this.totalInstructions,
    required this.totalAccounts,
    required this.programNames,
  });

  @override
  String toString() {
    return 'WorkspaceStats('
        'programs: $programCount, '
        'instructions: $totalInstructions, '
        'accounts: $totalAccounts'
        ')';
  }
}

/// Workspace builder for fluent API
class WorkspaceBuilder {
  final AnchorProvider _provider;
  final Map<String, ProgramConfig> _programConfigs = {};

  WorkspaceBuilder(this._provider);

  /// Add a program configuration
  WorkspaceBuilder addProgram(String name, ProgramConfig config) {
    _programConfigs[name] = config;
    return this;
  }

  /// Add program with IDL and program ID
  WorkspaceBuilder addProgramWithIdl(
    String name,
    Idl idl,
    PublicKey programId,
  ) {
    _programConfigs[name] = ProgramConfig(
      idl: idl,
      programId: programId,
      name: name,
    );
    return this;
  }

  /// Build the workspace
  Future<Workspace> build() async {
    final workspace = Workspace(_provider);
    await workspace.loadPrograms(_programConfigs);
    return workspace;
  }
}
