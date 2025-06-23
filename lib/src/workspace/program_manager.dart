/// Multi-program management and coordination system for Anchor programs
///
/// This module provides comprehensive multi-program management matching TypeScript's
/// unified program interface and coordination capabilities with shared resources
/// and dependency resolution.

library;

import 'dart:async';
import '../types/public_key.dart';
import '../idl/idl.dart';
import '../program/program_class.dart';
import '../provider/anchor_provider.dart';
import 'workspace_config.dart';

/// Exception thrown during program management operations
class ProgramManagerException implements Exception {
  final String message;
  final String? programName;
  final dynamic cause;

  const ProgramManagerException(
    this.message, {
    this.programName,
    this.cause,
  });

  @override
  String toString() {
    final buffer = StringBuffer('ProgramManagerException: $message');
    if (programName != null) {
      buffer.write(' (program: $programName)');
    }
    if (cause != null) {
      buffer.write('\nCaused by: $cause');
    }
    return buffer.toString();
  }
}

/// Program dependency definition with version constraints
class ProgramDependency {
  final String name;
  final PublicKey? programId;
  final String? version;
  final bool required;
  final List<String> features;

  const ProgramDependency({
    required this.name,
    this.programId,
    this.version,
    this.required = true,
    this.features = const [],
  });

  factory ProgramDependency.fromMap(Map<String, dynamic> map) {
    return ProgramDependency(
      name: map['name'] as String,
      programId: map['programId'] != null
          ? PublicKey.fromBase58(map['programId'] as String)
          : null,
      version: map['version'] as String?,
      required: map['required'] as bool? ?? true,
      features: (map['features'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      if (programId != null) 'programId': programId!.toBase58(),
      if (version != null) 'version': version,
      'required': required,
      if (features.isNotEmpty) 'features': features,
    };
  }
}

/// Program metadata with dependency information
class ProgramMetadata {
  final String name;
  final PublicKey programId;
  final Idl idl;
  final String? version;
  final List<ProgramDependency> dependencies;
  final Map<String, dynamic> metadata;
  final DateTime? loadedAt;

  const ProgramMetadata({
    required this.name,
    required this.programId,
    required this.idl,
    this.version,
    this.dependencies = const [],
    this.metadata = const {},
    this.loadedAt,
  });

  factory ProgramMetadata.fromProgram(
    String name,
    Program program, {
    List<ProgramDependency>? dependencies,
    Map<String, dynamic>? metadata,
  }) {
    return ProgramMetadata(
      name: name,
      programId: program.programId,
      idl: program.idl,
      version: program.idl.version,
      dependencies: dependencies ?? [],
      metadata: metadata ?? {},
      loadedAt: DateTime.now(),
    );
  }

  ProgramMetadata copyWith({
    String? name,
    PublicKey? programId,
    Idl? idl,
    String? version,
    List<ProgramDependency>? dependencies,
    Map<String, dynamic>? metadata,
    DateTime? loadedAt,
  }) {
    return ProgramMetadata(
      name: name ?? this.name,
      programId: programId ?? this.programId,
      idl: idl ?? this.idl,
      version: version ?? this.version,
      dependencies: dependencies ?? this.dependencies,
      metadata: metadata ?? this.metadata,
      loadedAt: loadedAt ?? this.loadedAt,
    );
  }
}

/// Program lifecycle state tracking
enum ProgramLifecycleState {
  unloaded,
  loading,
  loaded,
  initializing,
  ready,
  error,
  disposed,
}

/// Program lifecycle information
class ProgramLifecycleInfo {
  final ProgramLifecycleState state;
  final DateTime? stateChangedAt;
  final String? errorMessage;
  final Map<String, dynamic> stateData;

  const ProgramLifecycleInfo({
    required this.state,
    this.stateChangedAt,
    this.errorMessage,
    this.stateData = const {},
  });

  factory ProgramLifecycleInfo.initial() {
    return ProgramLifecycleInfo(
      state: ProgramLifecycleState.unloaded,
      stateChangedAt: DateTime.now(),
    );
  }

  ProgramLifecycleInfo transition(
    ProgramLifecycleState newState, {
    String? errorMessage,
    Map<String, dynamic>? stateData,
  }) {
    return ProgramLifecycleInfo(
      state: newState,
      stateChangedAt: DateTime.now(),
      errorMessage: errorMessage,
      stateData: stateData ?? this.stateData,
    );
  }

  bool get isReady => state == ProgramLifecycleState.ready;
  bool get isLoaded =>
      state == ProgramLifecycleState.loaded ||
      state == ProgramLifecycleState.ready;
  bool get hasError => state == ProgramLifecycleState.error;
  bool get isLoading =>
      state == ProgramLifecycleState.loading ||
      state == ProgramLifecycleState.initializing;
}

/// Centralized program registry with dependency tracking
class ProgramRegistry {
  final Map<String, Program> _programs = {};
  final Map<String, ProgramMetadata> _metadata = {};
  final Map<String, ProgramLifecycleInfo> _lifecycle = {};
  final Map<PublicKey, Set<String>> _programIdIndex = {};
  final Map<String, Set<String>> _dependencyGraph = {};
  final Map<String, Set<String>> _reverseDependencyGraph = {};

  /// Get all registered program names
  List<String> get programNames => _programs.keys.toList();

  /// Get all programs
  Map<String, Program> get programs => Map.unmodifiable(_programs);

  /// Get all program metadata
  Map<String, ProgramMetadata> get metadata => Map.unmodifiable(_metadata);

  /// Register a program in the registry
  void registerProgram(
    String name,
    Program program, {
    List<ProgramDependency>? dependencies,
    Map<String, dynamic>? metadata,
  }) {
    if (_programs.containsKey(name)) {
      throw ProgramManagerException(
        'Program already registered',
        programName: name,
      );
    }

    _programs[name] = program;
    _metadata[name] = ProgramMetadata.fromProgram(
      name,
      program,
      dependencies: dependencies,
      metadata: metadata,
    );
    _lifecycle[name] =
        ProgramLifecycleInfo.initial().transition(ProgramLifecycleState.loaded);

    // Update program ID index
    _programIdIndex.putIfAbsent(program.programId, () => <String>{}).add(name);

    // Update dependency graph
    if (dependencies != null) {
      _dependencyGraph[name] = dependencies.map((dep) => dep.name).toSet();

      for (final dep in dependencies) {
        _reverseDependencyGraph
            .putIfAbsent(dep.name, () => <String>{})
            .add(name);
      }
    }
  }

  /// Unregister a program from the registry
  bool unregisterProgram(String name) {
    final program = _programs.remove(name);
    if (program == null) {
      return false;
    }

    final meta = _metadata.remove(name);
    _lifecycle.remove(name);

    // Update program ID index
    if (meta != null) {
      _programIdIndex[meta.programId]?.remove(name);
      if (_programIdIndex[meta.programId]?.isEmpty == true) {
        _programIdIndex.remove(meta.programId);
      }
    }

    // Update dependency graph
    _dependencyGraph.remove(name);
    _reverseDependencyGraph.remove(name);

    // Remove from reverse dependencies
    for (final deps in _reverseDependencyGraph.values) {
      deps.remove(name);
    }

    // Update lifecycle state
    _lifecycle[name] =
        _lifecycle[name]?.transition(ProgramLifecycleState.disposed) ??
            ProgramLifecycleInfo.initial()
                .transition(ProgramLifecycleState.disposed);

    return true;
  }

  /// Get a program by name
  Program? getProgram(String name) {
    return _programs[name];
  }

  /// Get programs by program ID
  List<Program> getProgramsById(PublicKey programId) {
    final names = _programIdIndex[programId] ?? <String>{};
    return names.map((name) => _programs[name]!).toList();
  }

  /// Get program metadata by name
  ProgramMetadata? getProgramMetadata(String name) {
    return _metadata[name];
  }

  /// Get program lifecycle info
  ProgramLifecycleInfo? getLifecycleInfo(String name) {
    return _lifecycle[name];
  }

  /// Update program lifecycle state
  void updateLifecycleState(
    String name,
    ProgramLifecycleState state, {
    String? errorMessage,
    Map<String, dynamic>? stateData,
  }) {
    final current = _lifecycle[name];
    if (current != null) {
      _lifecycle[name] = current.transition(
        state,
        errorMessage: errorMessage,
        stateData: stateData,
      );
    } else {
      // Create initial lifecycle info if it doesn't exist
      _lifecycle[name] = ProgramLifecycleInfo.initial().transition(
        state,
        errorMessage: errorMessage,
        stateData: stateData,
      );
    }
  }

  /// Check if program exists
  bool hasProgram(String name) {
    return _programs.containsKey(name);
  }

  /// Get program dependencies
  List<ProgramDependency> getDependencies(String name) {
    return _metadata[name]?.dependencies ?? [];
  }

  /// Get programs that depend on the given program
  List<String> getDependents(String name) {
    return _reverseDependencyGraph[name]?.toList() ?? [];
  }

  /// Resolve dependency order for initialization
  List<String> resolveDependencyOrder([List<String>? programNames]) {
    final programs = programNames ?? this.programNames;
    final resolved = <String>[];
    final visiting = <String>{};
    final visited = <String>{};

    void visit(String program) {
      if (visited.contains(program)) {
        return;
      }

      if (visiting.contains(program)) {
        throw ProgramManagerException(
          'Circular dependency detected',
          programName: program,
        );
      }

      visiting.add(program);

      final dependencies = _dependencyGraph[program] ?? <String>{};
      for (final dep in dependencies) {
        if (programs.contains(dep)) {
          visit(dep);
        }
      }

      visiting.remove(program);
      visited.add(program);
      resolved.add(program);
    }

    for (final program in programs) {
      visit(program);
    }

    return resolved;
  }

  /// Validate all dependencies are satisfied
  List<String> validateDependencies() {
    final errors = <String>[];

    for (final entry in _metadata.entries) {
      final programName = entry.key;
      final metadata = entry.value;

      for (final dep in metadata.dependencies) {
        if (dep.required && !hasProgram(dep.name)) {
          errors.add(
              'Program $programName requires missing dependency: ${dep.name}');
        }

        if (dep.programId != null) {
          final depProgram = getProgram(dep.name);
          if (depProgram != null && depProgram.programId != dep.programId) {
            errors.add(
              'Program $programName dependency ${dep.name} has wrong program ID: '
              'expected ${dep.programId}, got ${depProgram.programId}',
            );
          }
        }
      }
    }

    return errors;
  }

  /// Clear all programs from registry
  void clear() {
    for (final name in _programs.keys.toList()) {
      unregisterProgram(name);
    }
  }

  /// Get registry statistics
  Map<String, dynamic> getStats() {
    final stateCount = <ProgramLifecycleState, int>{};
    for (final lifecycle in _lifecycle.values) {
      stateCount[lifecycle.state] = (stateCount[lifecycle.state] ?? 0) + 1;
    }

    return {
      'totalPrograms': _programs.length,
      'totalDependencies': _dependencyGraph.values
          .map((deps) => deps.length)
          .fold<int>(0, (a, b) => a + b),
      'stateCount': stateCount.map((key, value) => MapEntry(key.name, value)),
      'programIds': _programIdIndex.length,
    };
  }
}

/// Shared resource manager for efficient resource sharing across programs
class SharedResourceManager {
  final Map<String, AnchorProvider> _providers = {};
  final Map<String, dynamic> _sharedCache = {};
  final Map<String, StreamController<dynamic>> _eventStreams = {};

  /// Register a shared provider
  void registerProvider(String name, AnchorProvider provider) {
    _providers[name] = provider;
  }

  /// Get a shared provider
  AnchorProvider? getProvider(String name) {
    return _providers[name];
  }

  /// Get or create a shared cache entry
  T? getCachedValue<T>(String key) {
    return _sharedCache[key] as T?;
  }

  /// Set a shared cache entry
  void setCachedValue<T>(String key, T value) {
    _sharedCache[key] = value;
  }

  /// Get or create an event stream
  Stream<T> getEventStream<T>(String streamName) {
    final controller = _eventStreams.putIfAbsent(
      streamName,
      () => StreamController<T>.broadcast(),
    ) as StreamController<T>;

    return controller.stream;
  }

  /// Emit an event to a stream
  void emitEvent<T>(String streamName, T event) {
    final controller = _eventStreams[streamName] as StreamController<T>?;
    if (controller != null && !controller.isClosed) {
      controller.add(event);
    }
  }

  /// Clear all shared resources
  void clear() {
    _providers.clear();
    _sharedCache.clear();

    for (final controller in _eventStreams.values) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    _eventStreams.clear();
  }

  /// Get resource usage statistics
  Map<String, dynamic> getStats() {
    return {
      'providers': _providers.length,
      'cachedEntries': _sharedCache.length,
      'eventStreams': _eventStreams.length,
      'activeStreams': _eventStreams.values
          .where((controller) => !controller.isClosed)
          .length,
    };
  }
}

/// Multi-program coordination manager with shared resources and lifecycle management
class ProgramManager {
  final ProgramRegistry _registry = ProgramRegistry();
  final SharedResourceManager _resourceManager = SharedResourceManager();
  final Map<String, Completer<Program>> _loadingPrograms = {};

  /// Get the program registry
  ProgramRegistry get registry => _registry;

  /// Get the shared resource manager
  SharedResourceManager get resourceManager => _resourceManager;

  /// Register a program with coordination support
  Future<void> registerProgram(
    String name,
    Program program, {
    List<ProgramDependency>? dependencies,
    Map<String, dynamic>? metadata,
    bool autoInitialize = true,
  }) async {
    try {
      _registry.registerProgram(
        name,
        program,
        dependencies: dependencies,
        metadata: metadata,
      );

      if (autoInitialize) {
        await initializeProgram(name);
      }
    } catch (e) {
      _registry.updateLifecycleState(
        name,
        ProgramLifecycleState.error,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  /// Load and register a program from workspace configuration
  Future<Program> loadProgram(
    String name,
    WorkspaceConfig workspaceConfig,
    AnchorProvider provider, {
    String? cluster,
    bool autoInitialize = true,
  }) async {
    // Check if already loading
    if (_loadingPrograms.containsKey(name)) {
      return _loadingPrograms[name]!.future;
    }

    final completer = Completer<Program>();
    _loadingPrograms[name] = completer;

    try {
      _registry.updateLifecycleState(name, ProgramLifecycleState.loading);

      // Load IDL from workspace config
      final idl = workspaceConfig.loadProgramIdl(name, cluster);
      if (idl == null) {
        throw ProgramManagerException(
          'IDL not found for program',
          programName: name,
        );
      }

      // Get program entry for address
      final programEntry = workspaceConfig.getProgram(name, cluster);
      if (programEntry?.address == null) {
        throw ProgramManagerException(
          'Program address not found',
          programName: name,
        );
      }

      final programId = PublicKey.fromBase58(programEntry!.address!);
      final program = Program.withProgramId(idl, programId, provider: provider);

      await registerProgram(
        name,
        program,
        autoInitialize: autoInitialize,
      );

      completer.complete(program);
      return program;
    } catch (e) {
      _registry.updateLifecycleState(
        name,
        ProgramLifecycleState.error,
        errorMessage: e.toString(),
      );
      completer.completeError(e);
    } finally {
      _loadingPrograms.remove(name);
    }

    return completer.future;
  }

  /// Initialize a program and its dependencies
  Future<void> initializeProgram(String name) async {
    final program = _registry.getProgram(name);
    if (program == null) {
      throw ProgramManagerException(
        'Program not found',
        programName: name,
      );
    }

    try {
      _registry.updateLifecycleState(name, ProgramLifecycleState.initializing);

      // Initialize dependencies first
      final dependencies = _registry.getDependencies(name);
      for (final dep in dependencies) {
        if (dep.required && _registry.hasProgram(dep.name)) {
          final depLifecycle = _registry.getLifecycleInfo(dep.name);
          if (depLifecycle?.state != ProgramLifecycleState.ready) {
            await initializeProgram(dep.name);
          }
        }
      }

      // Mark as ready
      _registry.updateLifecycleState(name, ProgramLifecycleState.ready);
    } catch (e) {
      _registry.updateLifecycleState(
        name,
        ProgramLifecycleState.error,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  /// Initialize all programs in dependency order
  Future<void> initializeAll() async {
    final dependencyOrder = _registry.resolveDependencyOrder();

    for (final programName in dependencyOrder) {
      final lifecycle = _registry.getLifecycleInfo(programName);
      if (lifecycle?.state == ProgramLifecycleState.loaded) {
        await initializeProgram(programName);
      }
    }
  }

  /// Get a program with automatic loading if not present
  Future<Program?> getProgram(String name) async {
    final program = _registry.getProgram(name);
    if (program != null) {
      return program;
    }

    // Check if currently loading
    if (_loadingPrograms.containsKey(name)) {
      return _loadingPrograms[name]!.future;
    }

    return null;
  }

  /// Batch initialize multiple programs
  Future<void> batchInitialize(List<String> programNames) async {
    final dependencyOrder = _registry.resolveDependencyOrder(programNames);

    for (final name in dependencyOrder) {
      if (programNames.contains(name)) {
        await initializeProgram(name);
      }
    }
  }

  /// Validate all program dependencies
  void validateDependencies() {
    final errors = _registry.validateDependencies();
    if (errors.isNotEmpty) {
      throw ProgramManagerException(
        'Dependency validation failed:\n${errors.join('\n')}',
      );
    }
  }

  /// Get coordination statistics
  Map<String, dynamic> getStats() {
    return {
      'registry': _registry.getStats(),
      'resources': _resourceManager.getStats(),
      'loadingPrograms': _loadingPrograms.length,
    };
  }

  /// Dispose all programs and cleanup resources
  Future<void> dispose() async {
    // Cancel any loading operations
    for (final completer in _loadingPrograms.values) {
      if (!completer.isCompleted) {
        completer.completeError(
          ProgramManagerException('Program manager disposed'),
        );
      }
    }
    _loadingPrograms.clear();

    // Clear registry and resources
    _registry.clear();
    _resourceManager.clear();
  }
}
