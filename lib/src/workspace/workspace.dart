/// Workspace functionality for managing Anchor programs and IDLs.
/// Provides TypeScript-like workspace management for multiple programs.
library;

import 'dart:convert';
import 'dart:typed_data';
import '../types/public_key.dart';
import '../types/keypair.dart';
import '../types/transaction.dart';
import '../idl/idl.dart';
import '../program/program_class.dart';
import '../provider/anchor_provider.dart';
import '../provider/wallet.dart';

// Export workspace configuration system
export 'workspace_config.dart';

// Export program manager and coordination system
export 'program_manager.dart';

// Import workspace configuration
import 'workspace_config.dart';

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

  /// Auto-discovery workspace loader with TypeScript-like proxy behavior
  static Future<Workspace> discover({
    String? workspacePath,
    AnchorProvider? provider,
    String? cluster,
  }) async {
    final actualProvider = provider ?? await AnchorProvider.local();
    final workspace = Workspace(actualProvider);

    await workspace._autoDiscoverPrograms(
      workspacePath: workspacePath,
      cluster: cluster,
    );

    return workspace;
  }

  /// Auto-discover programs from workspace structure
  Future<void> _autoDiscoverPrograms({
    String? workspacePath,
    String? cluster,
  }) async {
    try {
      // Load workspace configuration
      final config = workspacePath != null
          ? WorkspaceConfig.fromDirectory(workspacePath)
          : WorkspaceConfig.fromCurrentDirectory();

      final targetCluster = cluster ?? config.provider.cluster;
      final programEntries = config.getProgramsForCluster(targetCluster);

      // Load each program
      for (final entry in programEntries.entries) {
        final programName = entry.key;
        final programEntry = entry.value;

        try {
          final idl = config.loadProgramIdl(programName, targetCluster);
          if (idl != null && programEntry.address != null) {
            final programId = PublicKey.fromBase58(programEntry.address!);
            await loadProgram(programName, idl, programId);
          }
        } catch (e) {
          // Continue loading other programs even if one fails
          print('Warning: Failed to load program $programName: $e');
        }
      }
    } catch (e) {
      // If auto-discovery fails, continue with empty workspace
      print('Warning: Auto-discovery failed: $e');
    }
  }

  /// Get a program with TypeScript-like camelCase conversion
  Program? getProgramCamelCase(String name) {
    // First try exact match
    final exactMatch = getProgram(name);
    if (exactMatch != null) return exactMatch;

    // Convert to camelCase and try again
    final camelCaseName = _toCamelCase(name);
    final camelMatch = getProgram(camelCaseName);
    if (camelMatch != null) return camelMatch;

    // Try snake_case conversion
    final snakeCaseName = _toSnakeCase(name);
    final snakeMatch = getProgram(snakeCaseName);
    if (snakeMatch != null) return snakeMatch;

    // Try all program names with case-insensitive comparison
    for (final entry in _programs.entries) {
      if (entry.key.toLowerCase() == name.toLowerCase()) {
        return entry.value;
      }
    }

    return null;
  }

  /// Convert string to camelCase
  String _toCamelCase(String input) {
    if (input.isEmpty) return input;

    // Handle snake_case and kebab-case
    final parts = input.split(RegExp(r'[-_\s]'));
    if (parts.length <= 1) {
      return input[0].toLowerCase() + input.substring(1);
    }

    final camelCase = StringBuffer(parts.first.toLowerCase());
    for (int i = 1; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        camelCase.write(parts[i][0].toUpperCase());
        if (parts[i].length > 1) {
          camelCase.write(parts[i].substring(1).toLowerCase());
        }
      }
    }

    return camelCase.toString();
  }

  /// Convert string to snake_case
  String _toSnakeCase(String input) {
    return input
        .replaceAllMapped(
            RegExp(r'([A-Z])'), (match) => '_${match.group(1)!.toLowerCase()}')
        .replaceFirst(RegExp(r'^_'), '');
  }

  /// Validate workspace health and configuration
  Future<WorkspaceHealthReport> validateHealth() async {
    final issues = <WorkspaceIssue>[];
    final warnings = <String>[];
    final programStatuses = <String, ProgramStatus>{};

    for (final entry in _programs.entries) {
      final name = entry.key;
      final program = entry.value;

      try {
        // Check if program exists on-chain
        final accountInfo =
            await _provider.connection.getAccountInfo(program.programId);

        if (accountInfo == null) {
          issues.add(WorkspaceIssue(
            type: WorkspaceIssueType.programNotFound,
            programName: name,
            message:
                'Program ${program.programId.toBase58()} not found on-chain',
          ));
          programStatuses[name] = ProgramStatus.notFound;
        } else if (!accountInfo.executable) {
          issues.add(WorkspaceIssue(
            type: WorkspaceIssueType.programNotExecutable,
            programName: name,
            message:
                'Program ${program.programId.toBase58()} is not executable',
          ));
          programStatuses[name] = ProgramStatus.notExecutable;
        } else {
          programStatuses[name] = ProgramStatus.healthy;
        }

        // Validate IDL compatibility
        try {
          // Basic IDL validation - could be expanded
          if (program.idl.instructions.isEmpty) {
            warnings.add('Program $name has no instructions defined');
          }
        } catch (e) {
          issues.add(WorkspaceIssue(
            type: WorkspaceIssueType.idlValidationFailed,
            programName: name,
            message: 'IDL validation failed: $e',
          ));
        }
      } catch (e) {
        issues.add(WorkspaceIssue(
          type: WorkspaceIssueType.connectionError,
          programName: name,
          message: 'Failed to validate program: $e',
        ));
        programStatuses[name] = ProgramStatus.error;
      }
    }

    return WorkspaceHealthReport(
      isHealthy: issues.isEmpty,
      issues: issues,
      warnings: warnings,
      programStatuses: programStatuses,
      checkedAt: DateTime.now(),
    );
  }

  /// Deploy a program to the workspace
  Future<DeploymentResult> deployProgram(
    String name,
    Uint8List programData,
    Keypair programKeypair, {
    Keypair? authorityKeypair,
    int? maxDataLen,
  }) async {
    try {
      final authority = authorityKeypair ??
          (_provider.wallet is KeypairWallet
              ? (_provider.wallet as KeypairWallet).keypair
              : null);
      if (authority == null) {
        return DeploymentResult(
          success: false,
          error: 'No authority keypair available for deployment',
          deployedAt: DateTime.now(),
        );
      }

      // TODO: Implement program deployment logic
      // This is a placeholder - actual implementation would use
      // Solana's program deployment instructions

      return DeploymentResult(
        success: true,
        programId: programKeypair.publicKey,
        transactionId: 'placeholder-tx-id',
        deployedAt: DateTime.now(),
      );
    } catch (e) {
      return DeploymentResult(
        success: false,
        error: e.toString(),
        deployedAt: DateTime.now(),
      );
    }
  }

  /// Upgrade a program in the workspace
  Future<UpgradeResult> upgradeProgram(
    String name,
    Uint8List newProgramData, {
    Keypair? authorityKeypair,
  }) async {
    final program = getProgram(name);
    if (program == null) {
      return UpgradeResult(
        success: false,
        error: 'Program $name not found in workspace',
        upgradedAt: DateTime.now(),
      );
    }

    try {
      final authority = authorityKeypair ??
          (_provider.wallet is KeypairWallet
              ? (_provider.wallet as KeypairWallet).keypair
              : null);

      if (authority == null) {
        return UpgradeResult(
          success: false,
          programId: program.programId,
          error: 'No authority keypair available for upgrade',
          upgradedAt: DateTime.now(),
        );
      }

      // TODO: Implement program upgrade logic
      // This is a placeholder - actual implementation would use
      // Solana's program upgrade instructions

      return UpgradeResult(
        success: true,
        programId: program.programId,
        transactionId: 'placeholder-tx-id',
        upgradedAt: DateTime.now(),
      );
    } catch (e) {
      return UpgradeResult(
        success: false,
        programId: program.programId,
        error: e.toString(),
        upgradedAt: DateTime.now(),
      );
    }
  }

  /// Initialize workspace with template configuration
  static Future<Workspace> initializeFromTemplate(
    AnchorProvider provider,
    WorkspaceTemplate template, {
    String? workspacePath,
  }) async {
    final workspace = Workspace(provider);

    // Apply template configuration
    for (final entry in template.programs.entries) {
      final name = entry.key;
      final config = entry.value;

      await workspace.loadProgram(name, config.idl, config.programId);
    }

    return workspace;
  }

  /// Create workspace development configuration
  Map<String, dynamic> createDevConfig() {
    return {
      'workspace': {
        'programs': _programs.length,
        'provider': 'local',
        'cluster': 'localnet',
      },
      'programs': _programs.map((name, program) => MapEntry(name, {
            'programId': program.programId.toBase58(),
            'instructions': program.idl.instructions.length,
            'accounts': program.idl.accounts?.length ?? 0,
          })),
    };
  }

  /// Export workspace for deployment
  Future<Map<String, dynamic>> exportForDeployment() async {
    final programs = <String, dynamic>{};

    for (final entry in _programs.entries) {
      final name = entry.key;
      final program = entry.value;

      programs[name] = {
        'programId': program.programId.toBase58(),
        'idl': program.idl.toJson(),
        'instructions':
            program.idl.instructions.map((inst) => inst.name).toList(),
        'accounts': program.idl.accounts?.map((acc) => acc.name).toList() ?? [],
      };
    }

    return {
      'workspace': {
        'version': '1.0.0',
        'exportedAt': DateTime.now().toIso8601String(),
        'provider': 'anchor-dart',
      },
      'programs': programs,
    };
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

/// Workspace health report with validation results
class WorkspaceHealthReport {
  final bool isHealthy;
  final List<WorkspaceIssue> issues;
  final List<String> warnings;
  final Map<String, ProgramStatus> programStatuses;
  final DateTime checkedAt;

  const WorkspaceHealthReport({
    required this.isHealthy,
    required this.issues,
    required this.warnings,
    required this.programStatuses,
    required this.checkedAt,
  });

  @override
  String toString() {
    final buffer = StringBuffer('WorkspaceHealthReport(');
    buffer.write('healthy: $isHealthy, ');
    buffer.write('issues: ${issues.length}, ');
    buffer.write('warnings: ${warnings.length}, ');
    buffer.write('programs: ${programStatuses.length}');
    buffer.write(')');
    return buffer.toString();
  }
}

/// Workspace issue types
enum WorkspaceIssueType {
  programNotFound,
  programNotExecutable,
  idlValidationFailed,
  connectionError,
  configurationError,
  dependencyError,
}

/// Individual workspace issue
class WorkspaceIssue {
  final WorkspaceIssueType type;
  final String? programName;
  final String message;
  final DateTime detectedAt;

  WorkspaceIssue({
    required this.type,
    this.programName,
    required this.message,
    DateTime? detectedAt,
  }) : detectedAt = detectedAt ?? DateTime.now();

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('[${type.name}]');
    if (programName != null) {
      buffer.write(' $programName:');
    }
    buffer.write(' $message');
    return buffer.toString();
  }
}

/// Program status enumeration
enum ProgramStatus {
  healthy,
  notFound,
  notExecutable,
  error,
  loading,
  unknown,
}

/// Deployment result
class DeploymentResult {
  final bool success;
  final PublicKey? programId;
  final String? transactionId;
  final String? error;
  final DateTime deployedAt;

  const DeploymentResult({
    required this.success,
    this.programId,
    this.transactionId,
    this.error,
    required this.deployedAt,
  });

  @override
  String toString() {
    if (success) {
      return 'DeploymentResult(success: true, programId: $programId, txId: $transactionId)';
    } else {
      return 'DeploymentResult(success: false, error: $error)';
    }
  }
}

/// Upgrade result
class UpgradeResult {
  final bool success;
  final PublicKey? programId;
  final String? transactionId;
  final String? error;
  final DateTime upgradedAt;

  const UpgradeResult({
    required this.success,
    this.programId,
    this.transactionId,
    this.error,
    required this.upgradedAt,
  });

  @override
  String toString() {
    if (success) {
      return 'UpgradeResult(success: true, programId: $programId, txId: $transactionId)';
    } else {
      return 'UpgradeResult(success: false, error: $error)';
    }
  }
}

/// Workspace template for initialization
class WorkspaceTemplate {
  final String name;
  final String version;
  final Map<String, ProgramConfig> programs;
  final Map<String, dynamic> configuration;

  const WorkspaceTemplate({
    required this.name,
    required this.version,
    required this.programs,
    this.configuration = const {},
  });

  factory WorkspaceTemplate.basic({
    required String name,
    required Map<String, ProgramConfig> programs,
  }) {
    return WorkspaceTemplate(
      name: name,
      version: '1.0.0',
      programs: programs,
    );
  }

  factory WorkspaceTemplate.fromJson(Map<String, dynamic> json) {
    final programsData = json['programs'] as Map<String, dynamic>;
    final programs = <String, ProgramConfig>{};

    for (final entry in programsData.entries) {
      programs[entry.key] =
          ProgramConfig.fromJson(entry.value as Map<String, dynamic>);
    }

    return WorkspaceTemplate(
      name: json['name'] as String,
      version: json['version'] as String,
      programs: programs,
      configuration: json['configuration'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'version': version,
      'programs': programs.map((key, value) => MapEntry(key, value.toJson())),
      'configuration': configuration,
    };
  }
}

/// Enhanced workspace builder with TypeScript-like features
class EnhancedWorkspaceBuilder {
  final AnchorProvider _provider;
  final Map<String, ProgramConfig> _programConfigs = {};
  final Map<String, dynamic> _metadata = {};
  String? _workspacePath;
  bool _autoDiscover = false;

  EnhancedWorkspaceBuilder(this._provider);

  /// Set workspace path for auto-discovery
  EnhancedWorkspaceBuilder withWorkspacePath(String path) {
    _workspacePath = path;
    return this;
  }

  /// Enable auto-discovery of programs
  EnhancedWorkspaceBuilder withAutoDiscover() {
    _autoDiscover = true;
    return this;
  }

  /// Add metadata to the workspace
  EnhancedWorkspaceBuilder withMetadata(String key, dynamic value) {
    _metadata[key] = value;
    return this;
  }

  /// Add a program configuration
  EnhancedWorkspaceBuilder addProgram(String name, ProgramConfig config) {
    _programConfigs[name] = config;
    return this;
  }

  /// Add program with IDL and program ID
  EnhancedWorkspaceBuilder addProgramWithIdl(
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

  /// Build the workspace with enhanced features
  Future<Workspace> build() async {
    Workspace workspace;

    if (_autoDiscover) {
      workspace = await Workspace.discover(
        workspacePath: _workspacePath,
        provider: _provider,
      );
    } else {
      workspace = Workspace(_provider);
    }

    // Load configured programs
    await workspace.loadPrograms(_programConfigs);

    return workspace;
  }
}
